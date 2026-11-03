---
id: m10-l05
title: Associated types, some and any
description: You write protocols with associated types, see why two any Equatable values can't be compared, use opaque some return types where the function picks the type, use some in parameters where the caller picks it, understand what an any box costs, and choose between them.
module: m10
order: 5
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m10-l04]
objectives:
  - Declare a protocol with an associatedtype and conform to it, letting Swift infer the type.
  - Explain why any Equatable values can't be compared with ==.
  - Write a function with a some return type and say who picks the concrete type.
  - Write a function with a some parameter and say who picks the concrete type.
  - Describe in plain words what an any box stores and what it costs.
  - Choose some or any for a parameter, a return type, a property and a collection.
terms:
  - term: Associated type
    definition: "A placeholder type inside a protocol, declared with associatedtype. Each conforming type decides what it is: for Sequence the Element, for a Container the Item."
  - term: Self requirement
    definition: "A requirement that mentions the conforming type itself, like Equatable's static func == (lhs: Self, rhs: Self). It works like an associated type that's always the conformer."
  - term: Existential type (any P)
    definition: "A box that can hold a value of any type conforming to P, chosen at run time, and different from box to box. It hides the concrete type from the compiler."
  - term: Opaque type (some P)
    definition: "One specific type conforming to P that the compiler knows but the code doesn't name. In a return type, the function picks it; in a parameter, the caller does."
  - term: Generic function
    definition: "A function with a type parameter, like func f<T: Shape>(_ value: T). Each call fixes T to one concrete type. Covered in Module 11; some in a parameter is shorthand for it."
mastery:
  - Write a protocol with an associatedtype and two conforming types that use different types for it.
  - Read "binary operator '==' cannot be applied to two 'any Equatable' operands" and explain it.
  - Write a function returning some P and fix "return statements in its body do not have matching underlying types".
  - "Rewrite func f(_ x: any Shape) as func f(_ x: some Shape) and say what changed."
  - Explain why [any Shape] can mix types and [some Shape] can't.
  - Name one situation where any is the right choice.
resources: [swift-book-protocols, swift-book-opaque-types, swift-book-generics]
cards:
  - id: m10-l05-c1
    front: What's an associatedtype?
    back: "A placeholder type in a protocol that each conforming type fills in, usually by inference. Sequence's Element is one: Int for [Int], Character for String."
  - id: m10-l05-c2
    front: "Why doesn't `let a: any Equatable = 1; let b: any Equatable = \"1\"; a == b` compile?"
    back: "== needs both sides to be the same type. Two any boxes could hold different types (here Int and String), and the compiler can't know, so it refuses."
  - id: m10-l05-c3
    front: "func makeShape() -> some Shape. Who picks the concrete type, and what's the rule?"
    back: "The function does. It must return the same concrete type on every path. Callers only know it's some Shape, but the compiler knows the real type."
  - id: m10-l05-c4
    front: "func draw(_ shape: some Shape). Who picks the type?"
    back: "The caller, at each call. It's shorthand for the generic func draw<S: Shape>(_ shape: S) (SE-0341)."
  - id: m10-l05-c5
    front: some or any by default?
    back: "some. Use any when one variable or collection must hold different conforming types at run time; the box then costs a little (possible heap allocation, indirect calls, no specialization)."
---

## The idea in one sentence

`some P` means "one specific type that conforms to `P`, which the compiler knows", `any P` means "a box that could hold any conforming type, decided at run time", and protocols with associated types are where the difference stops being academic.

## Associated types

Some protocols need to talk about a type they don't know yet. A container holds items, but of what type?

```swift
protocol Container {
    associatedtype Item
    var items: [Item] { get }
    mutating func add(_ item: Item)
}

struct Shelf: Container {
    var items: [String] = []

    mutating func add(_ item: String) {
        items.append(item)
    }
}

struct Piggybank: Container {
    var items: [Int] = []

    mutating func add(_ item: Int) {
        items.append(item)
    }
}

var shelf = Shelf()
shelf.add("Dune")
shelf.add("Emma")

var bank = Piggybank()
bank.add(50)
bank.add(20)

print(shelf.items)
print(bank.items)
```

```output
["Dune", "Emma"]
[50, 20]
```

1. `associatedtype Item` declares a placeholder. The protocol uses it in its requirements: an array of `Item`, a method that takes an `Item`.
2. `Shelf` implements `add(_ item: String)`, so Swift **infers** that for `Shelf`, `Item` is `String`. For `Piggybank` it's `Int`. You can also say it explicitly with `typealias Item = String` inside the type.

The standard library is full of these. `Sequence` has an associated type `Element`: `Int` for `[Int]`, `Character` for `String`. That's how `for x in something` knows the type of `x`.

### Self requirements

`Equatable` has no `associatedtype`, but it has the same kind of hole. Its requirement is:

```swift illustrative
static func == (lhs: Self, rhs: Self) -> Bool
```

`Self` means "the conforming type". For `Int` it's `Int == Int`; for `String`, `String == String`. Never `Int == String`. That's a requirement tied to the conforming type, and it behaves just like an associated type.

## Why two any Equatable values can't be compared

`any Equatable` is a valid type. You can put an `Int` in one box and a `String` in another:

```swift no-compile binary operator '==' cannot be applied to two 'any Equatable' operands
let first: any Equatable = 42
let second: any Equatable = "42"
print(first == second)
```

Swift 6.3: `error: binary operator '==' cannot be applied to two 'any Equatable' operands`. Think about what it would have to do. `==` needs both sides to be the **same** type, and the boxes hide which type each holds. Here they don't even match: one holds an `Int`, the other a `String`. The compiler can't check it, so it refuses, even when both boxes happen to hold `Int`s.

The same thing happens with `any Container`. You can create one and read from it, but adding an item would need to know what `Item` is:

```swift no-compile member 'add' cannot be used on value of type 'any Container'
protocol Container {
    associatedtype Item
    var items: [Item] { get }
    mutating func add(_ item: Item)
}

struct Shelf: Container {
    var items: [String] = []
    mutating func add(_ item: String) {
        items.append(item)
    }
}

var box: any Container = Shelf()
box.add("Dune")
```

The error continues "consider using a generic constraint instead". That's the hint: the fix is to keep the concrete type known to the compiler. That's what `some` and generics do.

> [!note] Writing any is required for these
> For a protocol with an associated type or a `Self` requirement, Swift 6.3 warns if you leave out `any` (`func f(_ c: Container)`): "use of protocol 'Container' as a type must be written 'any Container'; this will be an error in a future Swift language mode". Write `any` always and you won't see it.

## some in parameters: the caller picks

Here's a function that works with any container, written with `some`:

```swift
protocol Container {
    associatedtype Item
    var items: [Item] { get }
    mutating func add(_ item: Item)
}

struct Shelf: Container {
    var items: [String] = []
    mutating func add(_ item: String) {
        items.append(item)
    }
}

struct Piggybank: Container {
    var items: [Int] = []
    mutating func add(_ item: Int) {
        items.append(item)
    }
}

func summary(of container: some Container) -> String {
    "\(container.items.count) items, first: \(container.items.first.map { "\($0)" } ?? "none")"
}

func duplicateFirst(in container: inout some Container) {
    if let first = container.items.first {
        container.add(first)
    }
}

var shelf = Shelf(items: ["Dune", "Emma"])
var bank = Piggybank(items: [50])
duplicateFirst(in: &shelf)
duplicateFirst(in: &bank)
print(summary(of: shelf))
print(summary(of: bank))
print(shelf.items)
```

```output
3 items, first: Dune
2 items, first: 50
["Dune", "Emma", "Dune"]
```

`some Container` in a parameter means: **the caller** passes one concrete type, and inside the function the compiler knows it's that type, whatever it is. That's why `duplicateFirst` can call `add`: `first` is a `container.items` element, so it's exactly the `Item` that `add` expects. With `any Container`, that line wouldn't compile.

`some` in a parameter is shorthand (since Swift 5.7, SE-0341) for a **generic function**, the subject of Module 11:

```swift illustrative
func summary(of container: some Container) -> String
// means the same as
func summary<C: Container>(of container: C) -> String
```

At each call site, `C` is fixed to one type: `Shelf` for the first call, `Piggybank` for the second. The compiler can even produce a specialized copy of the function for each, with direct calls instead of witness-table lookups.

### Two some parameters are two different types

```swift no-compile conflicting arguments to generic parameter 'Self'
func same(_ first: some Equatable, _ second: some Equatable) -> Bool {
    first == second
}
```

Each `some` is its own type parameter. The caller could pass an `Int` and a `String`, so `==` between them is rejected (the Swift 6.3 message mentions "conflicting arguments to generic parameter 'Self'"). To require the **same** type twice, you need a named generic parameter: `func same<T: Equatable>(_ first: T, _ second: T) -> Bool`. You'll write those in Module 11.

### Passing an any where a some is expected

If you already have a box, you can pass it to a `some` parameter. Swift opens the box and calls the function with the concrete type inside (SE-0352, Swift 5.7):

```swift
protocol Shape {
    var area: Double { get }
}

struct Square: Shape {
    let side: Double
    var area: Double { side * side }
}

struct Circle: Shape {
    let radius: Double
    var area: Double { 3.14 * radius * radius }
}

func label(for shape: some Shape) -> String {
    "area \(shape.area)"
}

let shapes: [any Shape] = [Square(side: 2), Circle(radius: 1)]
for shape in shapes {
    print(label(for: shape))
}
```

```output
area 4.0
area 3.14
```

## some in return types: the function picks

The other direction: an **opaque return type**. The function decides what concrete type to return; the caller only knows it conforms to the protocol.

```swift
protocol Shape {
    var area: Double { get }
}

struct Square: Shape {
    let side: Double
    var area: Double { side * side }
}

func makeTile(size: Double) -> some Shape {
    Square(side: size)
}

let tile = makeTile(size: 3)
print(tile.area)
```

```output
9.0
```

The caller writes `tile.area` and nothing else about `Square` leaks out. The function can switch to a different shape type later without breaking any caller. That's the point: **hide the type, keep the speed**. Unlike a box, the compiler still knows `tile` is a `Square`, so calls are direct.

The rule (SE-0244): a `some` return type stands for **one** type. Every `return` in the function must return the same concrete type.

```swift no-compile do not have matching underlying types
protocol Shape {
    var area: Double { get }
}

struct Square: Shape {
    let side: Double
    var area: Double { side * side }
}

struct Circle: Shape {
    let radius: Double
    var area: Double { 3.14 * radius * radius }
}

func makeShape(round: Bool) -> some Shape {
    if round {
        return Circle(radius: 1)
    }
    return Square(side: 1)
}
```

Swift 6.3: `error: function declares an opaque return type 'some Shape', but the return statements in its body do not have matching underlying types`. If the type really depends on a run-time condition, `some` is the wrong tool; return `any Shape`.

Because the type is fixed, things the box can't do work again. Two values from the same opaque function have the same type, so `==` compiles:

```swift
func makeOrderNumber() -> some Equatable {
    1042
}

let first = makeOrderNumber()
let second = makeOrderNumber()
print(first == second)
```

```output
true
```

You'll see `some` returns constantly in SwiftUI: every view has `var body: some View`. The body's real type is a long nested generic type that nobody wants to write; `some View` says "a view, the compiler knows which".

## What an any box costs

A value of type `any Shape` is stored in a container, an **existential box**, that holds three things: the value itself (or a reference to it), the value's real type, and that type's witness table for `Shape`.

In plain words, compared to a value whose concrete type the compiler knows:

- **Storage.** The box has a fixed size. Small values fit inside it; bigger ones are stored separately on the heap, which costs an allocation. Class instances are already references, so the box just holds the reference. (The exact size of the inline space is an implementation detail.)
- **Calls.** Every requirement call goes through the witness table: an indirect call, and the compiler usually can't inline it.
- **Optimization.** The compiler can't specialize code for a type it doesn't know.
- **Type information.** Anything that depends on `Self` or an associated type is limited: no `==` between two boxes, no `add` on `any Container`, and associated types come out erased (reading `items` from an `any Container` gives you `[Any]`).

None of this makes `any` bad. A box is the only way to hold a square and a circle in one array. But it's a real trade, so make it on purpose.

## Choosing between some and any

| You need | Use |
| --- | --- |
| A parameter that accepts any conforming type | `some P` (one type per call) |
| To return a conforming value without exposing its type | `some P` (the function always returns the same type) |
| One collection holding different conforming types | `[any P]` |
| A property or variable whose concrete type can change at run time | `any P` |
| To return different types depending on a condition | `any P` |

The rule of thumb: **write `some` first, and switch to `any` when you actually need different types in the same place at run time.** The compiler will tell you when `some` can't work (as in the mismatched returns above).

A shape gallery that uses both:

```swift
protocol Shape {
    var name: String { get }
    var area: Double { get }
}

struct Square: Shape {
    let side: Double
    var name: String { "square" }
    var area: Double { side * side }
}

struct Circle: Shape {
    let radius: Double
    var name: String { "circle" }
    var area: Double { 3.14 * radius * radius }
}

struct Gallery {
    var shapes: [any Shape] = []

    mutating func add(_ shape: some Shape) {
        shapes.append(shape)
    }

    func largest() -> (any Shape)? {
        var best: (any Shape)? = nil
        for shape in shapes {
            if shape.area > (best?.area ?? -1) {
                best = shape
            }
        }
        return best
    }
}

func describe(_ shape: some Shape) -> String {
    "\(shape.name) (\(shape.area))"
}

var gallery = Gallery()
gallery.add(Square(side: 2))
gallery.add(Circle(radius: 2))
gallery.add(Square(side: 3))

if let biggest = gallery.largest() {
    print("Largest: \(describe(biggest))")
}
print("Count: \(gallery.shapes.count)")
```

```output
Largest: circle (12.56)
Count: 3
```

- `shapes` must hold squares and circles together, so it's `[any Shape]`.
- `add` takes `some Shape`: each call passes one concrete type, and appending it puts it in a box.
- `largest()` returns `(any Shape)?`, because the answer could be either type. The parentheses make the whole `any Shape` optional.
- `describe` takes `some Shape`; passing `biggest`, an `any Shape`, opens the box.

## Common mistakes

> [!error] error: binary operator '==' cannot be applied to two 'any Equatable' operands
> The boxes could hold different types. Keep the values' concrete type known: use a concrete type, `some`, or a generic parameter shared by both values (Module 11).

> [!error] error: member 'add' cannot be used on value of type 'any Container'
> The method's parameter uses the associated type, which the box hides. Take `some Container` instead.

> [!error] error: function declares an opaque return type … do not have matching underlying types
> A `some` return must be one concrete type on every path. Return the same type, or return `any P`.

> [!error] Expecting two some parameters to be the same type
> `func f(_ a: some P, _ b: some P)` lets the caller pass two different types. Use a named generic parameter when they must match.

> [!error] Reaching for any by habit
> `func render(_ shape: any Shape)` works, but `some Shape` does the same job for a single value without the box. Use `any` when you need the mix.

````exercise
id: m10-l05-e1
type: comprehension
prompt: "Who picks the concrete type in each case? `func a() -> some Shape` and `func b(_ s: some Shape)`."
choices:
  - text: "a: the caller. b: the function."
    correct: false
    why: It's the other way around.
  - text: "a: the function. b: the caller."
    correct: true
    why: "An opaque return type is chosen by the function's body (SE-0244). A some parameter is a generic parameter, fixed by each call (SE-0341)."
  - text: "Both are picked at run time, like any."
    correct: false
    why: "Both are fixed at compile time. Only any defers the type to run time."
  - text: "Neither; some means the type can change between calls in both cases."
    correct: false
    why: "For a, it's the same type on every call. For b, each call can pass a different type, but within one call it's fixed."
solution: |
  **a: the function, b: the caller.** `some` always means "one specific type the compiler knows". The difference is who decides. In a return position the function's body decides and must always return that same type. In a parameter position each call decides, which makes it a generic function.
````

````exercise
id: m10-l05-e2
type: prediction
prompt: Predict the exact output.
code: |
  protocol Stack {
      associatedtype Element
      var elements: [Element] { get set }
  }

  extension Stack {
      mutating func push(_ element: Element) {
          elements.append(element)
      }
      var top: String {
          elements.last.map { "\($0)" } ?? "empty"
      }
  }

  struct Plates: Stack {
      var elements: [Int] = []
  }

  struct Words: Stack {
      var elements: [String] = []
  }

  func pushTopAgain(onto stack: inout some Stack) {
      if let last = stack.elements.last {
          stack.push(last)
      }
  }

  var plates = Plates()
  plates.push(7)
  plates.push(8)
  var words = Words()
  pushTopAgain(onto: &plates)
  pushTopAgain(onto: &words)
  print(plates.top, plates.elements.count)
  print(words.top, words.elements.count)
  words.push("hi")
  pushTopAgain(onto: &words)
  print(words.elements)
output: |
  8 3
  empty 0
  ["hi", "hi"]
hints:
  - "Element is inferred from elements: Int for Plates, String for Words."
  - "pushTopAgain does nothing when the stack is empty."
solution: |
  ```output
  8 3
  empty 0
  ["hi", "hi"]
  ```

  1. `plates` gets 7 and 8, then `pushTopAgain` pushes 8 again: three elements, top 8.
  2. `words` is empty, so `elements.last` is `nil` and nothing happens. `top` falls back to `"empty"`.
  3. After `push("hi")`, `pushTopAgain` pushes another `"hi"`.

  The interesting part is that `pushTopAgain` compiles at all. With `some Stack`, the compiler knows that inside one call `stack` has one concrete type, so `last` is exactly that type's `Element` and `push(last)` type-checks. Written with `inout any Stack`, the `push` call would be rejected, because the box hides which `Element` it expects.
````

````exercise
id: m10-l05-e3
type: fill-in
prompt: |
  Complete the code so it compiles and prints `true`. `makeToken()` should hide its concrete type, and the two tokens must be comparable.
code: |
  func makeToken() -> [[1]] Equatable {
      "abc-123"
  }

  let first = makeToken()
  let second = makeToken()
  print(first [[2]] second)
blanks:
  - id: "1"
    answers: ["some"]
  - id: "2"
    answers: ["=="]
solution: |
  ```swift
  func makeToken() -> some Equatable {
      "abc-123"
  }

  let first = makeToken()
  let second = makeToken()
  print(first == second)
  ```

  ```output
  true
  ```

  With `some Equatable`, both tokens have the same hidden type (it's `String`, but callers can't rely on that), so `==` is allowed. With `any Equatable`, they'd be two boxes and `==` wouldn't compile.
````

````exercise
id: m10-l05-e4
type: find-errors
prompt: Pick out the real problems.
code: |
  protocol Shape {
      var area: Double { get }
  }
  struct Square: Shape { let side: Double; var area: Double { side * side } }
  struct Circle: Shape { let radius: Double; var area: Double { 3.14 * radius * radius } }

  func randomShape(_ round: Bool) -> some Shape {
      if round {
          return Circle(radius: 1)
      }
      return Square(side: 1)
  }

  let a: any Equatable = 3
  let b: any Equatable = 3
  print(a == b)

  var shapes: [some Shape] = [Square(side: 1), Circle(radius: 2)]
choices:
  - text: randomShape returns two different concrete types from a some return.
    correct: true
    why: "A some return must be one type on every path. This function needs any Shape."
  - text: "a == b compares two any Equatable boxes."
    correct: true
    why: The compiler can't prove both boxes hold the same type, even though they do here.
  - text: "[some Shape] can't hold a Square and a Circle."
    correct: true
    why: "some Shape is one type. A mixed array needs [any Shape]."
  - text: "Square and Circle need to be classes to conform to Shape."
    correct: false
    why: Structs conform to protocols like any other type.
rubric:
  - randomShape returns any Shape.
  - The comparison uses concrete Int values.
  - The array is [any Shape].
solution: |
  ```swift
  protocol Shape {
      var area: Double { get }
  }
  struct Square: Shape { let side: Double; var area: Double { side * side } }
  struct Circle: Shape { let radius: Double; var area: Double { 3.14 * radius * radius } }

  func randomShape(_ round: Bool) -> any Shape {
      if round {
          return Circle(radius: 1)
      }
      return Square(side: 1)
  }

  let a = 3
  let b = 3
  print(a == b)

  let shapes: [any Shape] = [Square(side: 1), Circle(radius: 2), randomShape(true)]
  print(shapes.count, randomShape(false).area)
  ```

  ```output
  true
  3 1.0
  ```

  All three errors are the same mistake in different places: asking `some` to stand for more than one type, or asking `any` to keep type information it erased. When the type depends on a run-time condition, or a collection mixes types, use `any`. When you need `==`, keep the concrete type.
````

````exercise
id: m10-l05-e5
type: solve
prompt: |
  Write a protocol `Repository` with an associated type `Model` and two requirements:

  - `var all: [Model] { get }`
  - `mutating func save(_ model: Model)`

  Then `struct NoteRepository: Repository` that stores `String` notes, and `struct ScoreRepository: Repository` that stores `Int` scores.

  Finally, write `func countAll(_ repository: some Repository) -> Int` that returns the number of stored models, so this prints the output below:

  ```swift
  var notes = NoteRepository()
  notes.save("Buy milk")
  notes.save("Call Ana")
  var scores = ScoreRepository()
  scores.save(90)
  print(countAll(notes), countAll(scores))
  print(notes.all)
  ```

  ```output
  2 1
  ["Buy milk", "Call Ana"]
  ```
starter: |
  protocol Repository {
      // your code
  }
hints:
  - "associatedtype Model, then use Model in both requirements."
  - "Each struct needs a stored var all: [String] (or [Int]) and a mutating save."
  - "countAll only needs all.count, which works for any Model."
rubric:
  - The protocol declares associatedtype Model.
  - Each repository infers its own Model.
  - countAll takes some Repository, not any.
  - The output matches exactly.
solution: |
  ```swift
  protocol Repository {
      associatedtype Model
      var all: [Model] { get }
      mutating func save(_ model: Model)
  }

  struct NoteRepository: Repository {
      private(set) var all: [String] = []

      mutating func save(_ model: String) {
          all.append(model)
      }
  }

  struct ScoreRepository: Repository {
      private(set) var all: [Int] = []

      mutating func save(_ model: Int) {
          all.append(model)
      }
  }

  func countAll(_ repository: some Repository) -> Int {
      repository.all.count
  }

  var notes = NoteRepository()
  notes.save("Buy milk")
  notes.save("Call Ana")
  var scores = ScoreRepository()
  scores.save(90)
  print(countAll(notes), countAll(scores))
  print(notes.all)
  ```

  ```output
  2 1
  ["Buy milk", "Call Ana"]
  ```

  `Model` is inferred from `save`'s parameter and `all`'s element type. `countAll` works for both repositories because it only uses something that doesn't depend on `Model`'s concrete type. `private(set)` keeps `save` the only way to add data, and still satisfies `{ get }`. This repository shape will come back when you build persistence layers: one protocol, one implementation that stores in memory for tests, another that stores on disk.
````

````exercise
id: m10-l05-e6
type: design
prompt: |
  For each declaration, choose `some` or `any` and justify it in one sentence:

  1. A function `render(_ chart: ??? Chart)` that draws one chart.
  2. A dashboard's `var widgets: [??? Widget]`, which holds clocks, weather cards and calendars.
  3. A factory `func makeDefaultTheme() -> ??? Theme` that always returns `LightTheme`.
  4. A `var currentTheme: ??? Theme` the user can switch between `LightTheme` and `DarkTheme` at run time.
rubric:
  - "1: some, one chart of one type per call."
  - "2: any, the array mixes types."
  - "3: some, always the same type, hidden from callers."
  - "4: any, the stored type changes at run time."
solution: |
  1. **`some Chart`.** Each call draws one chart of one concrete type; no box needed.
  2. **`[any Widget]`.** The array holds different widget types side by side, which only a box can do.
  3. **`some Theme`.** The function always returns `LightTheme`; `some` hides that without boxing, and lets you change the type later without touching callers.
  4. **`any Theme`.** The variable holds a `LightTheme` now and a `DarkTheme` later. `some` would fix it to one type forever.

  The pattern: if the type is decided once (per call, or by the function), use `some`. If it varies in the same storage at run time, use `any`.
````

## Summary

- An `associatedtype` is a placeholder each conforming type fills in, usually by inference. `Self` requirements, like `Equatable`'s `==`, work the same way.
- `any P` is a box that hides the concrete type. That's why two `any Equatable` values can't be compared and why methods using an associated type can't be called on `any Container`.
- `some P` in a parameter: the caller picks the type; it's shorthand for a generic function (SE-0341). Two `some` parameters can be two different types.
- `some P` as a return type: the function picks one type and must return it on every path (SE-0244). The compiler keeps the type, so `==` and direct calls still work.
- An `any` box may allocate, calls through it are indirect, and the compiler can't specialize. Use it when you need different types in one place at run time.
- Default to `some`; switch to `any` for mixed collections, properties whose type changes, and returns that depend on a condition.
