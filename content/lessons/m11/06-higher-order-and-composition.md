---
id: m11-l06
title: Higher-order functions and composition
description: You write your own generic map, filter and grouped(by:), return functions from functions, compose small functions into bigger ones, use currying where it helps and skip it where it doesn't, weigh a chained pipeline against a plain loop, and close the module with a reusable form validator built from generics and closures.
module: m11
order: 6
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m11-l05]
objectives:
  - Implement map and filter yourself as generic functions and as an extension on Array.
  - Write a generic grouped(by:) on Sequence with a Hashable key.
  - Write functions that return functions, and explain why their captured parameters must be @escaping.
  - Compose two functions into one and build a pipeline from a list of steps.
  - Use currying or partial application where a fixed argument is reused, and explain when a normal function is clearer.
  - Choose between a chain of higher-order calls and a loop based on readability.
terms:
  - term: Higher-order function
    definition: "A function that takes a function as a parameter, returns one, or both. map, filter and reduce take one; a factory like multiplier(by:) returns one."
  - term: Function composition
    definition: "Combining two functions f: (A) -> B and g: (B) -> C into one function (A) -> C that runs f and then g."
  - term: Currying
    definition: "Turning a function of several parameters into a chain of functions of one parameter each: add(2)(3) instead of add(2, 3)."
  - term: Partial application
    definition: "Fixing some of a function's arguments now and getting back a function that takes the rest later, like taxed(rate: 0.21) returning (Double) -> Double."
  - term: Pipeline
    definition: "A sequence of transformations where each step's output is the next step's input, written as a chain of calls or as a composed function."
mastery:
  - Write myMap and myFilter as an Array extension and get the same results as map and filter.
  - "Write grouped(by:) returning [Key: [Element]] and print it in a stable order."
  - "Write compose(_:_:) and fix \"escaping closure captures non-escaping parameter\"."
  - Build a slug generator by composing small String -> String steps.
  - Rewrite a curried function as a normal one and say which reads better at the call site.
  - Split an unreadable chain into named steps or a loop.
resources: [swift-book-closures, swift-book-functions, swift-book-generics, swift-book-collection-types]
cards:
  - id: m11-l06-c1
    front: "What's the generic signature of your own map on Array?"
    back: "func myMap<T>(_ transform: (Element) -> T) -> [T], inside extension Array. Element comes from the array; T is chosen by each call."
  - id: m11-l06-c2
    front: "Why must compose's parameters be @escaping?"
    back: "compose returns a closure that captures f and g and calls them later, after compose has returned. Without @escaping: \"escaping closure captures non-escaping parameter\"."
  - id: m11-l06-c3
    front: "compose(f, g)(x) runs which function first?"
    back: "f, then g: it's g(f(x)). Name the parameters or the function (then, andThen) so the order is obvious."
  - id: m11-l06-c4
    front: When is currying worth it in Swift?
    back: "When one argument is fixed and reused across many calls (a tax rate, a prefix), so returning a configured function reads better. Otherwise use a normal multi-parameter function."
---

## The idea in one sentence

Once functions are values and generics let them work on any type, you can build your own `map`, `filter` and `grouped(by:)`, make functions that produce functions, and snap small functions together into bigger ones, as long as the result is still easy to read.

## Writing map yourself

You've used `map` since Module 7. Here it is from scratch, first as a free function:

```swift
func myMap<Input, Output>(_ items: [Input], _ transform: (Input) -> Output) -> [Output] {
    var result: [Output] = []
    for item in items {
        result.append(transform(item))
    }
    return result
}

let prices = [5, 12, 30]
print(myMap(prices) { price in price * 2 })
print(myMap(prices) { price in "$\(price)" })
```

```output
[10, 24, 60]
["$5", "$12", "$30"]
```

Two type parameters, because the input and output types are independent. `transform` is non-escaping: it's called inside the loop and forgotten. Nothing here is new; it's lesson 1 and Module 6 together.

The standard library's version is a method. Put yours in an extension on `Array`, where the array's own `Element` is already available:

```swift
extension Array {
    func myMap<Output>(_ transform: (Element) -> Output) -> [Output] {
        var result: [Output] = []
        for item in self {
            result.append(transform(item))
        }
        return result
    }

    func myFilter(_ isIncluded: (Element) -> Bool) -> [Element] {
        var result: [Element] = []
        for item in self where isIncluded(item) {
            result.append(item)
        }
        return result
    }
}

let words = ["swift", "is", "fun"]
print(words.myMap { $0.count })
print(words.myFilter { $0.count > 2 })
print(words.myMap { $0.count } == words.map { $0.count })
```

```output
[5, 2, 3]
["swift", "fun"]
true
```

`myMap` adds one type parameter, `Output`; `Element` comes from the array, as in lesson 2. `myFilter` needs none, because it returns the same element type it got. (The real `map` is declared on `Sequence`, so it works on sets, ranges and dictionaries too, and it supports closures that throw errors. Module 12 covers that part.)

## grouped(by:)

In Module 7 you grouped values with `Dictionary(grouping:by:)`. Writing it yourself shows where the generics go:

```swift
extension Sequence {
    func grouped<Key: Hashable>(by key: (Element) -> Key) -> [Key: [Element]] {
        var groups: [Key: [Element]] = [:]
        for element in self {
            groups[key(element), default: []].append(element)
        }
        return groups
    }
}

struct Expense {
    let category: String
    let amount: Int
}

let expenses = [
    Expense(category: "food", amount: 12),
    Expense(category: "travel", amount: 80),
    Expense(category: "food", amount: 7),
]

let byCategory = expenses.grouped { $0.category }
for category in byCategory.keys.sorted() {
    let amounts = byCategory[category, default: []].map { $0.amount }
    print(category, amounts)
}

let byLength = ["ox", "cat", "dog", "hi"].grouped { $0.count }
print(byLength[2, default: []], byLength[3, default: []])
```

```output
food [12, 7]
travel [80]
["ox", "hi"] ["cat", "dog"]
```

- The extension is on `Sequence`, so it works for arrays, sets and ranges alike. Inside it, `Element` is `Sequence`'s associated type.
- `Key: Hashable` is the constraint from lesson 3: dictionary keys need it. The caller's closure decides what the key is, a `String` in the first call and an `Int` in the second.
- `groups[key(element), default: []].append(element)` reads the group (or an empty array), appends, and writes it back, the same `default:` subscript you used for counting in Module 7.
- The keys are sorted before printing because a dictionary's order isn't defined.

## Functions that return functions

A higher-order function can also **return** a function. You did this with `makeCounter` in lesson 4. Here are two more useful shapes:

```swift
func multiplier(by factor: Int) -> (Int) -> Int {
    { value in value * factor }
}

func longerThan(_ length: Int) -> (String) -> Bool {
    { text in text.count > length }
}

let triple = multiplier(by: 3)
print(triple(7))
print([1, 2, 3].map(multiplier(by: 10)))
print(["hi", "hello", "hey there"].filter(longerThan(3)))
```

```output
21
[10, 20, 30]
["hello", "hey there"]
```

Each returned closure captures the parameter (`factor`, `length`) and uses it later. `map` and `filter` happily accept the returned function in place of a closure literal, because its type, `(Int) -> Int` or `(String) -> Bool`, is what they expect.

`longerThan(3)` reads almost like English at the call site. That's the main reason to write a function-returning function: it gives a name to a closure you'd otherwise retype.

## Composition

**Composing** two functions means making a new one that runs the first, then feeds the result to the second:

```swift
func compose<A, B, C>(_ first: @escaping (A) -> B, _ second: @escaping (B) -> C) -> (A) -> C {
    { value in second(first(value)) }
}

func addTax(_ cents: Int) -> Int {
    cents + cents * 21 / 100
}

func formatted(_ cents: Int) -> String {
    "$\(cents / 100)"
}

let priceLabel = compose(addTax, formatted)
print(priceLabel(1000))
print([500, 2000].map(priceLabel))
```

```output
$12
["$6", "$24"]
```

1. Three type parameters: `first` turns an `A` into a `B`, `second` turns a `B` into a `C`, and the result goes straight from `A` to `C`. The shared `B` is what makes them fit together; pass two functions whose types don't line up and the call won't compile.
2. `compose` returns a closure that calls `first` and `second` **later**, whenever someone calls `priceLabel`. That's escaping (lesson 5), so both parameters must be `@escaping`.
3. `compose(addTax, formatted)` runs `addTax` first. The order matters: `formatted` then `addTax` wouldn't even type-check.

Leave out the `@escaping` and Swift 6.3 says exactly what's wrong:

```swift no-compile escaping closure captures non-escaping parameter
func compose<A, B, C>(_ first: (A) -> B, _ second: (B) -> C) -> (A) -> C {
    { value in second(first(value)) }
}
```

`error: escaping closure captures non-escaping parameter 'first'` (and the same for `second`).

> [!note] Custom operators
> Some codebases define an operator such as `>>>` for composition so they can write `addTax >>> formatted`. Swift lets you declare operators, but a team has to learn each one. A named function is easier to search for and to read; prefer it unless the operator is used everywhere in a codebase.

### A pipeline of steps

When every step has the same type, `(T) -> T`, you can keep them in an array and fold them into one function. Here's a slug generator, the kind of thing that turns a blog title into a URL path:

```swift
func compose<A, B, C>(_ first: @escaping (A) -> B, _ second: @escaping (B) -> C) -> (A) -> C {
    { value in second(first(value)) }
}

func pipeline<T>(_ steps: [(T) -> T]) -> (T) -> T {
    var combined: (T) -> T = { value in value }
    for step in steps {
        combined = compose(combined, step)
    }
    return combined
}

let lowercase: (String) -> String = { $0.lowercased() }
let keepWordCharacters: (String) -> String = { text in
    text.filter { $0.isLetter || $0.isNumber || $0 == " " }
}
let hyphenate: (String) -> String = { text in
    text.split(separator: " ").joined(separator: "-")
}

let slug = pipeline([lowercase, keepWordCharacters, hyphenate])
print(slug("Generics & Closures in Swift 6!"))
print(slug("  Hello,   World  "))
```

```output
generics-closures-in-swift-6
hello-world
```

- `pipeline` starts from the **identity function**, `{ value in value }`, which returns its input unchanged, and composes each step onto it in order.
- `isLetter` and `isNumber` are `Character` properties; `filter` on a `String` keeps the characters that pass.
- `split(separator: " ")` breaks the text at spaces and drops empty pieces, which is why the extra spaces in the second title disappear. `joined(separator: "-")` glues the pieces back with hyphens.
- Each step is tiny and testable on its own. Adding "replace accented letters" later is one more closure in the array.

`pipeline` doesn't need `@escaping` on `steps`: an array of closures is already escaping, like an optional closure, because the closures are stored inside the array value.

## Currying, in moderation

**Currying** turns a function of several parameters into a chain of one-parameter functions:

```swift
func add(_ a: Int) -> (Int) -> Int {
    { b in a + b }
}

func taxed(rate: Double) -> (Double) -> Double {
    { price in price * (1 + rate) }
}

print(add(2)(3))

let spainVAT = taxed(rate: 0.21)
let germanyVAT = taxed(rate: 0.19)
print(spainVAT(100), germanyVAT(100))
print([10.0, 50.0].map(spainVAT))
```

```output
5
121.0 119.0
[12.1, 60.5]
```

`add(2)(3)` is curried for the sake of it, and it reads worse than `add(2, 3)`. Nobody calling it gains anything. `taxed(rate:)` is different: the rate is fixed once per country and the configured function is reused many times, including directly in `map`. That's **partial application**, and it's the useful part of currying.

Early versions of Swift had special syntax for declaring curried functions. It was removed in Swift 3 (SE-0002) because it was rarely used and confused people. Write a function that returns a closure, as above, when you want this; write a normal function the rest of the time.

## Pipelines vs readability

Chaining is great until it isn't. Both of these compute the same report:

```swift
struct Order {
    let customer: String
    let total: Int
    let isPaid: Bool
}

let orders = [
    Order(customer: "Ana", total: 120, isPaid: true),
    Order(customer: "Bo", total: 40, isPaid: false),
    Order(customer: "Ana", total: 60, isPaid: true),
    Order(customer: "Cy", total: 200, isPaid: true),
]

let chained = Dictionary(grouping: orders.filter { $0.isPaid }, by: { $0.customer }).mapValues { $0.reduce(0) { $0 + $1.total } }.filter { $0.value >= 150 }.keys.sorted()
print(chained)

let paidOrders = orders.filter { order in order.isPaid }
let totalsByCustomer = Dictionary(grouping: paidOrders) { order in order.customer }
    .mapValues { customerOrders in customerOrders.reduce(0) { sum, order in sum + order.total } }
let bigSpenders = totalsByCustomer
    .filter { entry in entry.value >= 150 }
    .keys
    .sorted()
print(bigSpenders)
```

```output
["Ana", "Cy"]
["Ana", "Cy"]
```

The first is one line and almost unreadable: five `$0`s that stand for four different things (an order, an array of orders, a running sum, a dictionary entry), and a `$1` in the middle. The second does the same work with named intermediate values and named closure parameters. `mapValues` transforms each value of a dictionary and keeps the keys.

Rules of thumb:

- **One line, one idea.** If a chain needs a comment to explain it, break it into named steps.
- **Name parameters** when a closure is nested or its parameter has properties you read.
- **A loop is fine.** If the logic has early exits, several accumulators or side effects, a `for` loop is usually clearer than a `reduce` that does three things.
- **Each step creates an array.** For a few hundred items that's irrelevant. For huge collections, measure before you optimize; the standard library has `lazy` sequences for that case, which you'll meet later.

## Putting it together: a reusable validator

This program combines the whole module: a generic type, constrained generic functions, function-returning functions, escaping closures stored in a struct, and composition.

```swift
struct Validator<Value> {
    private var rules: [(message: String, isValid: (Value) -> Bool)] = []

    func rule(_ message: String, _ isValid: @escaping (Value) -> Bool) -> Validator<Value> {
        var copy = self
        copy.rules.append((message: message, isValid: isValid))
        return copy
    }

    func errors(for value: Value) -> [String] {
        rules.filter { rule in !rule.isValid(value) }.map { rule in rule.message }
    }
}

func minLength(_ length: Int) -> (String) -> Bool {
    { text in text.count >= length }
}

func inRange<T: Comparable>(_ range: ClosedRange<T>) -> (T) -> Bool {
    { value in range.contains(value) }
}

func not<T>(_ predicate: @escaping (T) -> Bool) -> (T) -> Bool {
    { value in !predicate(value) }
}

let username = Validator<String>()
    .rule("At least 3 characters", minLength(3))
    .rule("No spaces", not { $0.contains(" ") })
    .rule("Not reserved", not { ["admin", "root"].contains($0) })

let age = Validator<Int>()
    .rule("Between 13 and 120", inRange(13...120))

for name in ["ana", "al", "big boss", "admin"] {
    let problems = username.errors(for: name)
    print(name, problems.isEmpty ? "OK" : problems.joined(separator: "; "))
}
print(age.errors(for: 9), age.errors(for: 30))
```

```output
ana OK
al At least 3 characters
big boss No spaces
admin Not reserved
["Between 13 and 120"] []
```

Walk through it:

1. `Validator<Value>` is a generic struct (lesson 2). The same type validates a `String` username and an `Int` age.
2. Each rule stores a message and a closure. `rule(_:_:)` stores the closure in the array, so its parameter is `@escaping` (lesson 5).
3. `rule` returns a modified **copy** instead of mutating, so calls chain: `Validator<String>().rule(…).rule(…)`. Because `Validator` is a struct, `username` and `age` can't affect each other or anything else.
4. `minLength(3)` and `inRange(13...120)` are functions that return predicates. `inRange` is generic with a `Comparable` constraint (lesson 3), so it also works for `Double` or `String` ranges.
5. `not` takes a predicate and returns the opposite one: a tiny composition helper. Its parameter is `@escaping` because the returned closure captures it.
6. `errors(for:)` is a plain `filter` then `map`, short enough to stay on one line.

Adding a rule is one line, any rule can be reused across validators of the same value type, and every piece can be tested alone. That's the payoff of treating functions as values.

## Common mistakes

> [!error] error: escaping closure captures non-escaping parameter
> A function returns a closure that uses one of its closure parameters. The returned closure outlives the call, so the parameter must be `@escaping`.

> [!error] Getting the composition order backwards
> `compose(f, g)` here means "f, then g". Mathematical notation (g ∘ f) reads the other way. Check the types: if `f`'s output doesn't match `g`'s input, the call won't compile, which usually catches it. When both are `(T) -> T`, it won't, so test it.

> [!error] Currying everything
> `add(2)(3)` is harder to read and to call than `add(2, 3)`. Return a configured function only when one argument is fixed and reused.

> [!error] The unreadable one-liner
> A chain with several nested `$0`s is a puzzle for the next reader. Name the intermediate results and the closure parameters.

> [!error] Calling the factory instead of passing its result, or the reverse
> `filter(longerThan)` passes the factory itself, of type `(Int) -> (String) -> Bool`, and doesn't compile. `filter(longerThan(3))` calls the factory and passes the predicate it returns.

````exercise
id: m11-l06-e1
type: comprehension
prompt: "With `compose(first, second)` defined as in this lesson, what does `compose(addOne, double)(5)` return, if `addOne` adds 1 and `double` multiplies by 2?"
choices:
  - text: "11"
    correct: false
    why: "That's double first, then addOne: 5 × 2 + 1."
  - text: "12"
    correct: true
    why: "addOne runs first (6), then double (12)."
  - text: "10"
    correct: false
    why: "That would only apply double."
  - text: "It doesn't compile, because both functions have the same type."
    correct: false
    why: "Same types are fine: A, B and C are all Int."
solution: |
  **12.** `compose` returns `{ value in second(first(value)) }`, so `first` runs on the input and `second` on its result: `double(addOne(5)) = double(6) = 12`. When both functions are `(Int) -> Int`, the compiler can't catch a reversed order, so the order has to be clear from the names.
````

````exercise
id: m11-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  func compose<A, B, C>(_ first: @escaping (A) -> B, _ second: @escaping (B) -> C) -> (A) -> C {
      { value in second(first(value)) }
  }

  func adding(_ amount: Int) -> (Int) -> Int {
      { value in value + amount }
  }

  let double: (Int) -> Int = { $0 * 2 }
  let describe: (Int) -> String = { "<\($0)>" }

  let a = compose(adding(3), double)
  let b = compose(double, adding(3))
  let c = compose(compose(double, double), describe)

  print(a(1), b(1))
  print(c(5))
  print([1, 2].map(compose(b, describe)))
output: |
  8 5
  <20>
  ["<5>", "<7>"]
hints:
  - "compose(f, g) runs f first."
  - "c doubles twice, then describes."
solution: |
  ```output
  8 5
  <20>
  ["<5>", "<7>"]
  ```

  1. `a` adds 3 then doubles: `(1 + 3) × 2 = 8`. `b` doubles then adds 3: `1 × 2 + 3 = 5`. Same pieces, different order, different result.
  2. `c` composes a composition: double, double, then describe. `5 × 4 = 20`, shown as `<20>`.
  3. `compose(b, describe)` is a function `(Int) -> String`, which `map` accepts directly. `b(1) = 5`, `b(2) = 7`.
````

````exercise
id: m11-l06-e3
type: fill-in
prompt: |
  Complete the extension so `myCompactMap` works like the standard `compactMap`: apply the transform and keep only the non-nil results.
code: |
  extension Array {
      func myCompactMap<Output>(_ transform: ([[1]]) -> Output?) -> [[[2]]] {
          var result: [Output] = []
          for item in self {
              if let value = transform(item) {
                  result.append(value)
              }
          }
          return result
      }
  }

  print(["4", "x", "15"].myCompactMap { Int($0) })
blanks:
  - id: "1"
    answers: ["Element"]
  - id: "2"
    answers: ["Output"]
solution: |
  ```swift
  extension Array {
      func myCompactMap<Output>(_ transform: (Element) -> Output?) -> [Output] {
          var result: [Output] = []
          for item in self {
              if let value = transform(item) {
                  result.append(value)
              }
          }
          return result
      }
  }

  print(["4", "x", "15"].myCompactMap { Int($0) })
  ```

  ```output
  [4, 15]
  ```

  The transform receives the array's `Element` and returns an optional `Output`. The result is a plain `[Output]`: `if let` drops the `nil`s. Here `Element` is `String` and `Output` is `Int`, inferred from `Int($0)`, which returns `Int?`.
````

````exercise
id: m11-l06-e4
type: refactor
prompt: |
  This works, but nobody wants to maintain it. Rewrite it so a reader can follow it in one pass, with the same output. Use named intermediate values and named closure parameters.
code: |
  let scores = ["ana": [70, 95, 88], "bo": [40, 55], "cy": [99]]
  print(scores.filter { $0.value.count > 1 }.mapValues { $0.reduce(0, +) / $0.count }.sorted { $0.value > $1.value }.map { "\($0.key): \($0.value)" })
rubric:
  - Splits the chain into named steps.
  - Names closure parameters instead of nested $0 and $1.
  - Keeps the same output.
solution: |
  ```swift
  let scores = ["ana": [70, 95, 88], "bo": [40, 55], "cy": [99]]

  let withSeveralScores = scores.filter { entry in entry.value.count > 1 }
  let averages = withSeveralScores.mapValues { values in
      values.reduce(0, +) / values.count
  }
  let ranked = averages.sorted { left, right in left.value > right.value }
  let lines = ranked.map { entry in "\(entry.key): \(entry.value)" }
  print(lines)
  ```

  ```output
  ["ana: 84", "bo: 47"]
  ```

  Each line now does one thing and its name says what: students with several scores, their averages, the ranking, the formatted lines. The closures name their parameters (`entry`, `values`, `left`, `right`), so you don't have to work out which `$0` is a dictionary entry and which is an array. `reduce(0, +)` stays as is: passing the `+` operator is short and clear. The averages are integer divisions: 253 / 3 = 84 and 95 / 2 = 47.
````

````exercise
id: m11-l06-e5
type: solve
prompt: |
  Write two generic higher-order functions:

  - `func both<T>(_ first: @escaping (T) -> Bool, _ second: @escaping (T) -> Bool) -> (T) -> Bool` that returns a predicate true only when both are true.
  - `func either<T>(_ first: @escaping (T) -> Bool, _ second: @escaping (T) -> Bool) -> (T) -> Bool` that returns a predicate true when at least one is true.

  Then make this print the output below:

  ```swift
  let isEven: (Int) -> Bool = { $0 % 2 == 0 }
  let isLarge: (Int) -> Bool = { $0 > 10 }
  let numbers = [4, 11, 12, 7]
  print(numbers.filter(both(isEven, isLarge)))
  print(numbers.filter(either(isEven, isLarge)))
  let shortName = both({ (name: String) in name.count <= 4 }, { $0.first == "A" })
  print(["Ana", "Alberto", "Bo"].filter(shortName))
  ```

  ```output
  [12]
  [4, 11, 12]
  ["Ana"]
  ```
starter: |
  func both<T>(_ first: @escaping (T) -> Bool, _ second: @escaping (T) -> Bool) -> (T) -> Bool {
      // your code
  }
hints:
  - "Return a closure that takes a value and calls both predicates on it."
  - "Use && in both and || in either. They short-circuit, so the second predicate may not run."
rubric:
  - Both functions are generic over T and return (T) -> Bool.
  - The parameters are @escaping because the returned closure captures them.
  - Works for Int and String predicates.
  - The output matches exactly.
solution: |
  ```swift
  func both<T>(_ first: @escaping (T) -> Bool, _ second: @escaping (T) -> Bool) -> (T) -> Bool {
      { value in first(value) && second(value) }
  }

  func either<T>(_ first: @escaping (T) -> Bool, _ second: @escaping (T) -> Bool) -> (T) -> Bool {
      { value in first(value) || second(value) }
  }

  let isEven: (Int) -> Bool = { $0 % 2 == 0 }
  let isLarge: (Int) -> Bool = { $0 > 10 }
  let numbers = [4, 11, 12, 7]
  print(numbers.filter(both(isEven, isLarge)))
  print(numbers.filter(either(isEven, isLarge)))
  let shortName = both({ (name: String) in name.count <= 4 }, { $0.first == "A" })
  print(["Ana", "Alberto", "Bo"].filter(shortName))
  ```

  ```output
  [12]
  [4, 11, 12]
  ["Ana"]
  ```

  Each function returns a new predicate that captures the two it was given, which is why both parameters are `@escaping`. `T` is inferred from the predicates: `Int` in the first two calls, `String` in the last, where the first closure's annotation `(name: String)` tells Swift what `T` is and lets the second closure use `$0.first`. Because `&&` and `||` short-circuit (lesson 5), `second` only runs when it can change the answer.
````

````exercise
id: m11-l06-e6
type: design
prompt: |
  A shop app has a product list with filters the user can toggle: "in stock", "under a price", "category is X", "rating at least N". Filters combine with AND, and new ones get added every few months.

  Sketch, in Swift-like signatures and a few sentences, how you'd model the filters using what you learned in this module. Say what's generic, what returns functions, and how the active filters become one predicate.
rubric:
  - Represents a filter as a predicate (Product) -> Bool, or a small struct holding one.
  - Uses function-returning helpers for parameterized filters (underPrice(_:), category(_:)).
  - Combines active filters into one predicate (a both-style helper, reduce, or allSatisfy).
  - Keeps it readable, and mentions where generics help (e.g. a reusable helper over T) without forcing them.
solution: |
  One reasonable design:

  ```swift
  struct Product {
      let name: String
      let price: Int
      let category: String
      let rating: Int
      let inStock: Bool
  }

  typealias Filter<T> = (T) -> Bool

  func underPrice(_ limit: Int) -> Filter<Product> {
      { product in product.price < limit }
  }

  func inCategory(_ name: String) -> Filter<Product> {
      { product in product.category == name }
  }

  func ratingAtLeast(_ stars: Int) -> Filter<Product> {
      { product in product.rating >= stars }
  }

  let inStock: Filter<Product> = { product in product.inStock }

  func all<T>(_ filters: [Filter<T>]) -> Filter<T> {
      { value in filters.allSatisfy { filter in filter(value) } }
  }

  let products = [
      Product(name: "Mug", price: 12, category: "kitchen", rating: 5, inStock: true),
      Product(name: "Lamp", price: 45, category: "home", rating: 4, inStock: true),
      Product(name: "Pan", price: 30, category: "kitchen", rating: 3, inStock: false),
  ]

  let active = [inStock, underPrice(40), inCategory("kitchen")]
  print(products.filter(all(active)).map { product in product.name })
  print(products.filter(all([])).count)
  ```

  ```output
  ["Mug"]
  3
  ```

  - A filter is just a predicate. `typealias Filter<T> = (T) -> Bool` gives it a name; a generic typealias is allowed and keeps `all` reusable for any type.
  - Parameterized filters are functions that return predicates, so the UI can build `underPrice(sliderValue)` on the fly.
  - The active filters live in an array (closures in an array are already escaping) and `all` turns them into one predicate with `allSatisfy`, which returns `true` for an empty list: no filters means everything shows.
  - Adding a filter is one new function. Nothing else changes.

  A struct per filter with a `title` and a predicate would be a good next step when the UI needs to show filter names. Generics aren't needed for `Product`-specific functions; `all` is generic because it doesn't care what it filters.
````

## Summary

- `map`, `filter` and friends are ordinary generic higher-order functions. Writing them yourself takes a loop, a type parameter for the output, and an extension so `Element` is available.
- `grouped(by:)` shows the constraints in action: `Key: Hashable` because it's a dictionary key.
- Functions can return functions. Returned closures capture the factory's parameters, so any closure parameters they capture must be `@escaping`.
- `compose(f, g)` runs `f` then `g`. A list of `(T) -> T` steps folds into one pipeline function, starting from the identity.
- Currying is worth it when a fixed argument is reused (partial application, like `taxed(rate:)`); otherwise write a normal function.
- Prefer named steps and named closure parameters over long `$0` chains. A loop is a fine answer.
- Generics plus closures give you small, reusable, testable pieces, like `Validator<Value>` with function-returning rules.
