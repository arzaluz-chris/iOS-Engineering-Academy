---
id: m11-l03
title: Constraints and where clauses
description: You limit type parameters to types that can do what your code needs with T Comparable, combine constraints, write where clauses that relate two types, add members only to some specializations with constrained extensions, make a generic type conform to a protocol only when its parameter does, constrain associated types, and use primary associated types like some Collection<Int>.
module: m11
order: 3
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m11-l02]
objectives:
  - Add a protocol constraint to a type parameter so the body can use that protocol's requirements.
  - Combine constraints with & and with several constrained parameters.
  - Write a where clause, including one that requires two associated types to be equal.
  - Write a constrained extension that adds members only when the type parameter meets a requirement.
  - Write a conditional conformance and explain how it differs from a constrained extension.
  - Constrain an associated type in a protocol and in a generic function.
  - Use primary associated types such as some Collection<Int> and declare one on your own protocol.
terms:
  - term: Type constraint
    definition: "A requirement on a type parameter, written <T: Comparable>. Callers can only use types that meet it, and in exchange the body can use what the protocol provides."
  - term: where clause
    definition: "A list of requirements after a signature or an extension header, like where T: Hashable or where C1.Element == C2.Element. It can express everything angle-bracket constraints can, plus same-type requirements."
  - term: Constrained extension
    definition: "An extension that applies only to some specializations, like extension Stack where Element: Numeric. Its members exist only for those types."
  - term: Conditional conformance
    definition: "A generic type conforming to a protocol only when its parameters meet requirements, like extension Stack: Equatable where Element: Equatable (Swift 4.1, SE-0143)."
  - term: Primary associated type
    definition: "An associated type a protocol lists in angle brackets, like Collection<Element>, so you can write some Collection<Int> or any Collection<Int> (Swift 5.7, SE-0346)."
mastery:
  - Fix "requires that 'T' conform to 'Comparable'" by adding the right constraint, no stronger than needed.
  - Write a generic function with a where clause that requires two sequences to have the same element type.
  - Add a sum property only to stacks of numbers, and read the error you get when you call it on a stack of strings.
  - Make a generic struct Equatable exactly when its element is, and use == on it.
  - Explain why [Profile] == [Profile] doesn't compile until Profile is Equatable.
  - "Rewrite <C: Collection>(_ c: C) where C.Element == Int as some Collection<Int>."
resources: [swift-book-generics, swift-book-protocols, swift-book-extensions]
cards:
  - id: m11-l03-c1
    front: "What does <T: Comparable> buy you inside the function?"
    back: "You can use <, >, min, max and sorting on T values. In exchange, callers can only pass types that conform to Comparable."
  - id: m11-l03-c2
    front: "Constrained extension vs conditional conformance?"
    back: "extension Stack where Element: Numeric adds members to some stacks. extension Stack: Equatable where Element: Equatable makes some stacks conform to a protocol, so they can be passed wherever Equatable is required."
  - id: m11-l03-c3
    front: "Why does [1, 2] == [1, 2] compile but [Profile] == [Profile] might not?"
    back: "Array conforms to Equatable conditionally: extension Array: Equatable where Element: Equatable. If Profile isn't Equatable, neither is [Profile]."
  - id: m11-l03-c4
    front: "What does where C1.Element == C2.Element mean?"
    back: "A same-type requirement: the two sequences can be different types, but they must hold the same element type."
  - id: m11-l03-c5
    front: "some Collection<Int> is shorthand for what?"
    back: "A generic parameter C: Collection with where C.Element == Int. It works because Collection declares Element as its primary associated type (SE-0346, Swift 5.7)."
---

## The idea in one sentence

A **constraint** like `<T: Comparable>` narrows which types a generic accepts, and in exchange lets its body use what those types are guaranteed to have; `where` clauses, constrained extensions and conditional conformances are the same idea applied to more places.

## T: Comparable

Lesson 1 ended with a function that didn't compile because it compared two unconstrained `T`s. Add a constraint and it does:

```swift
func larger<T: Comparable>(_ a: T, _ b: T) -> T {
    a > b ? a : b
}

print(larger(3, 9))
print(larger("pear", "apple"))
print(larger(2.5, -1.0))
```

```output
9
pear
2.5
```

1. `<T: Comparable>` reads "T, where T is any type that conforms to `Comparable`".
2. Inside the body, Swift now knows every `T` has `<` and `>`, so `a > b` compiles.
3. Callers can pass `Int`, `String`, `Double`, or your own `Comparable` types from Module 10. A type without an ordering is rejected at the call, not halfway through the function.

A constraint is a deal. **The function asks for less freedom from callers and gets more power in the body.** Ask for the weakest constraint that works. If you only need `==`, ask for `Equatable`, not `Comparable`: more types qualify, and the signature tells readers exactly what the function does with the values.

```swift
func positions<T: Equatable>(of target: T, in items: [T]) -> [Int] {
    var result: [Int] = []
    for (index, item) in items.enumerated() where item == target {
        result.append(index)
    }
    return result
}

print(positions(of: "a", in: ["a", "b", "a"]))
print(positions(of: 7, in: [1, 2, 3]))
```

```output
[0, 2]
[]
```

### Constraints on generic types

Types take constraints the same way. In lesson 2, `RecentItems` needed a `sameAs` closure on every call because it couldn't compare two `Item`s. Require `Equatable` and the closure goes away:

```swift
struct RecentItems<Item: Equatable> {
    let capacity: Int
    private(set) var items: [Item] = []

    init(capacity: Int) {
        self.capacity = capacity
    }

    mutating func add(_ item: Item) {
        items.removeAll { existing in existing == item }
        items.insert(item, at: 0)
        if items.count > capacity {
            items.removeLast()
        }
    }
}

var searches = RecentItems<String>(capacity: 3)
for term in ["swift", "generics", "closures", "swift", "enums"] {
    searches.add(term)
}
print(searches.items)
```

```output
["enums", "swift", "closures"]
```

This is exactly why `Dictionary` is declared `Dictionary<Key, Value> where Key: Hashable`, and `Set<Element>` requires `Element: Hashable`: their storage needs a hash for every key. `Value` has no constraint because the dictionary only stores it.

## Several constraints

A type parameter can need more than one protocol. Join them with `&`, the same composition you used in Module 10:

```swift
func uniqueSorted<T: Hashable & Comparable>(_ items: [T]) -> [T] {
    Array(Set(items)).sorted()
}

print(uniqueSorted([3, 1, 3, 2, 1]))
print(uniqueSorted(["b", "a", "b"]))
```

```output
[1, 2, 3]
["a", "b"]
```

`Set(items)` needs `Hashable`; `sorted()` needs `Comparable`. Each protocol is there because one line uses it.

Several type parameters can each have their own constraint, or none: `func index<Key: Hashable, Value>(_ items: [Value], by key: (Value) -> Key) -> [Key: Value]`.

## where clauses

Everything inside the angle brackets can also go in a `where` clause after the signature. These two are identical:

```swift illustrative
func larger<T: Comparable>(_ a: T, _ b: T) -> T
func larger<T>(_ a: T, _ b: T) -> T where T: Comparable
```

For a single constraint the angle-bracket form is shorter. A `where` clause earns its place in two situations: when the list gets long, and when you need a requirement that the angle brackets **can't** express, such as two types being equal.

```swift
func allItemsMatch<First: Sequence, Second: Sequence>(_ first: First, _ second: Second) -> Bool
where First.Element == Second.Element, First.Element: Equatable {
    Array(first) == Array(second)
}

let fromArray = [1, 2, 3]
let fromRange = 1...3
print(allItemsMatch(fromArray, fromRange))
print(allItemsMatch(["a", "b"], ["a", "c"]))
```

```output
true
false
```

Read the signature in parts:

1. `First: Sequence, Second: Sequence`: two type parameters, each some kind of sequence. They can be **different** types: here an `Array<Int>` and a `ClosedRange<Int>`.
2. `First.Element == Second.Element` is a **same-type requirement**. `Element` is `Sequence`'s associated type, the thing you get in a `for` loop. Whatever the two sequences are, they must produce the same element type.
3. `First.Element: Equatable` constrains that element type, so the elements can be compared.
4. The body converts both to arrays and uses `==`, which works because of the requirements above.

Pass an array of strings and a range of integers and the call is rejected. With literals, Swift 6.3 reports it as `cannot convert value of type 'String' to expected element type 'Int'`:

```swift no-compile cannot convert value of type 'String' to expected element type 'Int'
func allItemsMatch<First: Sequence, Second: Sequence>(_ first: First, _ second: Second) -> Bool
where First.Element == Second.Element, First.Element: Equatable {
    Array(first) == Array(second)
}

print(allItemsMatch(["a"], 1...3))
```

## Constrained extensions

A `where` clause on an extension makes its members exist only for some specializations. A stack can add up its items only when they're numbers:

```swift
struct Stack<Element> {
    private(set) var items: [Element] = []

    mutating func push(_ item: Element) {
        items.append(item)
    }
}

extension Stack where Element: Numeric {
    var total: Element {
        var sum: Element = 0
        for item in items {
            sum += item
        }
        return sum
    }
}

extension Stack where Element == String {
    var sentence: String {
        items.joined(separator: " ")
    }
}

var amounts = Stack<Double>()
amounts.push(2.5)
amounts.push(4)
print(amounts.total)

var words = Stack<String>()
words.push("generics")
words.push("rock")
print(words.sentence)
```

```output
6.5
generics rock
```

- `where Element: Numeric` (a standard protocol that `Int` and `Double` conform to, with `+`, `*` and a zero from the literal `0`) makes `total` available on `Stack<Int>`, `Stack<Double>` and so on.
- `where Element == String` is a same-type requirement: `sentence` exists only on `Stack<String>`. Since Swift 5.7 you can also write it as `extension Stack<String>` (SE-0361).
- Inside each extension, the body can use what the requirement provides: `+=` on `Element`, `joined` on an array of strings.

Ask for `total` on the wrong stack and the error names the missing requirement:

```swift no-compile property 'total' requires that 'String' conform to 'Numeric'
struct Stack<Element> {
    var items: [Element] = []
}

extension Stack where Element: Numeric {
    var total: Element {
        items.reduce(0, +)
    }
}

let words = Stack(items: ["a", "b"])
print(words.total)
```

You've used constrained extensions from the standard library for months. `[3, 1, 2].sorted()` without a closure and `max()` are declared in `extension Sequence where Element: Comparable`; `contains(_:)` lives in one `where Element: Equatable`. That's why `sorted()` works on `[Int]` but not on an array of a struct with no ordering.

## Conditional conformance

A constrained extension adds **members**. Sometimes you need the type itself to **conform to a protocol**, so it can go anywhere that protocol is required. Since Swift 4.1 (SE-0143) you can make a generic type conform only when its parameter does:

```swift
struct Stack<Element> {
    var items: [Element] = []
}

extension Stack: Equatable where Element: Equatable {}

func positions<T: Equatable>(of target: T, in items: [T]) -> [Int] {
    var result: [Int] = []
    for (index, item) in items.enumerated() where item == target {
        result.append(index)
    }
    return result
}

let a = Stack(items: [1, 2])
let b = Stack(items: [1, 2])
print(a == b)
print(a == Stack(items: [2, 1]))
print(positions(of: a, in: [b, Stack(items: []), a]))
```

```output
true
false
[0, 2]
```

1. `extension Stack: Equatable where Element: Equatable {}` says: a `Stack<X>` is `Equatable` whenever `X` is. The braces are empty because Swift synthesizes `==` (compare every stored property), as it did for structs in Module 10.
2. `a == b` works for `Stack<Int>`.
3. The last line is what a constrained extension couldn't give you: `Stack<Int>` is passed as `T` to a function that requires `T: Equatable`. The stack **is** `Equatable` now, not just a type with an `==` method.

A `Stack` of something non-equatable still compiles; it just isn't `Equatable`, and comparing two of them fails with `operator function '==' requires that '…' conform to 'Equatable'`.

The standard library does exactly this. `Array` is declared with `extension Array: Equatable where Element: Equatable`, and the same for `Hashable`. That's why:

```swift no-compile operator function '==' requires that 'Profile' conform to 'Equatable'
struct Profile {
    let name: String
}

let team = [Profile(name: "Ana")]
print(team == team)
```

`[Profile]` would be `Equatable` only if `Profile` were. Add `: Equatable` to `Profile` and the comparison compiles, because the array's conformance follows its element's.

| | Constrained extension | Conditional conformance |
| --- | --- | --- |
| Syntax | `extension Stack where Element: Numeric { … }` | `extension Stack: Equatable where Element: Equatable { … }` |
| Adds | Methods and properties | A protocol conformance (plus its requirements) |
| Usable as `T: Equatable`? | No | Yes |

## Constraints on associated types

Module 10's `Container` protocol had an `associatedtype Item` with no constraint. Associated types take constraints in two places.

**In the protocol**, when every conforming type must provide an item type with some ability:

```swift
protocol Inventory {
    associatedtype Item: Hashable
    var items: [Item] { get }
}

extension Inventory {
    var distinctCount: Int {
        Set(items).count
    }
}

struct Pantry: Inventory {
    var items: [String]
}

struct Bins: Inventory {
    var items: [Int]
}

print(Pantry(items: ["rice", "beans", "rice"]).distinctCount)
print(Bins(items: [4, 4, 4]).distinctCount)
```

```output
2
1
```

Because the protocol guarantees `Item: Hashable`, the protocol extension can build a `Set` for every conforming type. A type whose items aren't hashable can't conform at all.

**In a generic function or extension**, when only this function needs the extra ability:

```swift
protocol Container {
    associatedtype Item
    var items: [Item] { get }
}

struct Shelf: Container {
    var items: [String]
}

func containsAll<C: Container>(_ container: C, _ wanted: [C.Item]) -> Bool where C.Item: Equatable {
    for item in wanted where !container.items.contains(item) {
        return false
    }
    return true
}

let shelf = Shelf(items: ["Dune", "Emma", "Ulysses"])
print(containsAll(shelf, ["Emma", "Dune"]))
print(containsAll(shelf, ["Emma", "Hamlet"]))
```

```output
true
false
```

`C.Item` names the container's associated type. `where C.Item: Equatable` asks for `==` on items, which `contains(_:)` needs, without forcing every `Container` in the program to have equatable items.

## Primary associated types

Writing `<C: Collection>(_ numbers: C) where C.Element == Int` to say "any collection of `Int`s" is a mouthful. Since Swift 5.7 (SE-0346), protocols can list their most important associated type in angle brackets, and the standard library does this for `Sequence<Element>` and `Collection<Element>`. That lets you write the constraint inline:

```swift
func total(_ numbers: some Collection<Int>) -> Int {
    var sum = 0
    for number in numbers {
        sum += number
    }
    return sum
}

print(total([1, 2, 3]))
print(total(1...4))
print(total(Set([10])))
```

```output
6
10
10
```

`some Collection<Int>` means "a type parameter `C: Collection` with `C.Element == Int`". The array, the range and the set are three different types, and each call gets its own specialization. It also works with `any`: `[any Collection<Int>]`.

Your own protocols can declare one too:

```swift
protocol Container<Item> {
    associatedtype Item
    var items: [Item] { get }
}

struct Shelf: Container {
    var items: [String]
}

struct Piggybank: Container {
    var items: [Int]
}

func titles(in container: some Container<String>) -> String {
    container.items.joined(separator: ", ")
}

print(titles(in: Shelf(items: ["Dune", "Emma"])))
let mixed: [any Container<Int>] = [Piggybank(items: [5, 20])]
print(mixed[0].items)
```

```output
Dune, Emma
[5, 20]
```

`protocol Container<Item>` names `Item` as the primary associated type. `titles(in:)` accepts any container of strings: `Shelf` works, `Piggybank` would be rejected. Notice that `mixed[0].items` comes out as `[Int]`, not `[Any]`: unlike a plain `any Container` from Module 10, the box keeps the item type because you constrained it.

Pick the primary associated type the way the standard library does: the one callers most often want to pin down. For a container, that's the item.

## Common mistakes

> [!error] error: referencing operator function '>' on 'Comparable' requires that 'T' conform to 'Comparable'
> The body uses something the type parameter isn't guaranteed to have. Add the constraint that provides it, and no stronger.

> [!error] error: property 'total' requires that 'String' conform to 'Numeric'
> You called a member from a constrained extension on a specialization that doesn't meet the `where` clause. Either the call is wrong, or the extension's requirement is too strict.

> [!error] error: operator function '==' requires that 'Profile' conform to 'Equatable'
> Arrays, optionals, dictionaries and sets conform to `Equatable` only when their contents do. Make the element type `Equatable`.

> [!error] Expecting a constrained extension to add a conformance
> `extension Stack where Element: Equatable { static func == … }` gives some stacks an `==` method, but `Stack<Int>` still isn't `Equatable`: you can't pass it where `T: Equatable` is required. Write `extension Stack: Equatable where Element: Equatable`.

> [!error] Over-constraining
> `func positions<T: Comparable>` when the body only uses `==` rejects every type that's equatable but not ordered, for no reason. Constrain to what the body uses.

````exercise
id: m11-l03-e1
type: comprehension
prompt: "`Stack` has `extension Stack where Element: Hashable { var unique: Set<Element> { Set(items) } }`. Which statement is true?"
choices:
  - text: "Stack<Int> is now Hashable."
    correct: false
    why: "A constrained extension adds members, not conformances. For that you'd write extension Stack: Hashable where Element: Hashable."
  - text: "Stack<Int> has a unique property; a Stack of a non-hashable struct doesn't."
    correct: true
    why: "The member exists only for specializations that meet the where clause."
  - text: "Every Stack must now hold Hashable elements."
    correct: false
    why: "The extension restricts where its members apply, not what Stack can hold. Stack of anything still compiles."
  - text: "It doesn't compile; where clauses only go on functions."
    correct: false
    why: "Extensions take where clauses. The standard library is full of them."
solution: |
  **`Stack<Int>` gets `unique`; a stack of non-hashable elements doesn't.** A `where` clause on an extension filters which specializations see its members. It doesn't change what the type can hold (that would be a constraint on the type parameter itself, `struct Stack<Element: Hashable>`), and it doesn't add a protocol conformance (that's the `extension Stack: Protocol where …` form).
````

````exercise
id: m11-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  struct Pair<Value> {
      let first: Value
      let second: Value
  }

  extension Pair where Value: Comparable {
      var smaller: Value {
          min(first, second)
      }
  }

  extension Pair: Equatable where Value: Equatable {}

  extension Pair where Value == String {
      var joined: String {
          first + second
      }
  }

  let numbers = Pair(first: 8, second: 3)
  let words = Pair(first: "ab", second: "cd")
  print(numbers.smaller, words.smaller)
  print(words.joined)
  print(numbers == Pair(first: 8, second: 3), numbers == Pair(first: 3, second: 8))
  print([numbers, numbers].contains(Pair(first: 3, second: 8)))
output: |
  3 ab
  abcd
  true false
  false
hints:
  - "String is Comparable too, so words gets smaller."
  - "Synthesized == compares first with first and second with second."
solution: |
  ```output
  3 ab
  abcd
  true false
  false
  ```

  1. Both `Int` and `String` are `Comparable`, so both pairs have `smaller`. `"ab" < "cd"` alphabetically.
  2. `joined` exists only on `Pair<String>`.
  3. The conditional conformance makes `Pair<Int>` `Equatable` with a synthesized `==` that compares property by property. `(8, 3)` and `(3, 8)` differ, so the second comparison is `false`.
  4. `contains(_:)` on an array requires `Element: Equatable`. `Pair<Int>` qualifies thanks to the conditional conformance. The array holds two `(8, 3)` pairs, so `(3, 8)` isn't in it.
````

````exercise
id: m11-l03-e3
type: fill-in
prompt: |
  Complete the function so it returns the elements two sequences have in common, in the order they appear in the first. The sequences can be different types (an array and a range, say), but must hold the same, hashable element type.
code: |
  func common<First: Sequence, Second: Sequence>(_ first: First, _ second: Second) -> [First.Element]
  [[1]] First.Element [[2]] Second.Element, First.Element: [[3]] {
      let lookup = Set(second)
      var result: [First.Element] = []
      for item in first where lookup.contains(item) {
          result.append(item)
      }
      return result
  }

  print(common([5, 1, 9, 3], 1...5))
  print(common(["x", "y"], ["z"]))
blanks:
  - id: "1"
    answers: ["where"]
  - id: "2"
    answers: ["=="]
  - id: "3"
    answers: ["Hashable"]
solution: |
  ```swift
  func common<First: Sequence, Second: Sequence>(_ first: First, _ second: Second) -> [First.Element]
  where First.Element == Second.Element, First.Element: Hashable {
      let lookup = Set(second)
      var result: [First.Element] = []
      for item in first where lookup.contains(item) {
          result.append(item)
      }
      return result
  }

  print(common([5, 1, 9, 3], 1...5))
  print(common(["x", "y"], ["z"]))
  ```

  ```output
  [5, 1, 3]
  []
  ```

  `==` between the two `Element`s lets you put the second sequence's items in a set and look up the first's items in it: they're the same type. `Hashable` is needed for `Set(second)`. Since it's declared on `First.Element` and the two are the same type, `Second.Element` gets it too.
````

````exercise
id: m11-l03-e4
type: find-errors
prompt: This code has several problems. Which choices name a real one?
code: |
  func largest<T>(_ items: [T]) -> T? {
      var best = items.first
      for item in items {
          if let current = best, item > current {
              best = item
          }
      }
      return best
  }

  struct Tag {
      let name: String
  }

  extension Array where Element == Tag {
      var names: [String] { map { tag in tag.name } }
  }

  let tags = [Tag(name: "swift"), Tag(name: "ios")]
  print(tags.names)
  print(tags == tags)
  print(["a"].names)
choices:
  - text: "largest compares T values with > but T has no Comparable constraint."
    correct: true
    why: "The body needs Comparable; the signature has to ask for it."
  - text: "tags == tags fails because Tag isn't Equatable, so [Tag] isn't either."
    correct: true
    why: "Array is Equatable only when its Element is (conditional conformance)."
  - text: "[\"a\"].names fails: names only exists on arrays of Tag."
    correct: true
    why: "The extension's where Element == Tag excludes [String]."
  - text: "extension Array where Element == Tag isn't allowed on a standard library type."
    correct: false
    why: "You can extend standard types with constrained extensions. tags.names works."
rubric:
  - Adds T Comparable to largest.
  - Makes Tag Equatable (or removes the comparison).
  - Removes or fixes the names call on [String].
  - Doesn't flag the Array extension itself.
solution: |
  ```swift
  func largest<T: Comparable>(_ items: [T]) -> T? {
      var best = items.first
      for item in items {
          if let current = best, item > current {
              best = item
          }
      }
      return best
  }

  struct Tag: Equatable {
      let name: String
  }

  extension Array where Element == Tag {
      var names: [String] { map { tag in tag.name } }
  }

  let tags = [Tag(name: "swift"), Tag(name: "ios")]
  print(tags.names)
  print(tags == tags)
  print(largest([4, 9, 2]) ?? 0)
  ```

  ```output
  ["swift", "ios"]
  true
  9
  ```

  Three real problems, three kinds of constraint: a missing constraint on a function's type parameter, a conditional conformance that doesn't apply because the element type lacks `Equatable`, and a constrained extension called on a specialization it excludes.
````

````exercise
id: m11-l03-e5
type: solve
prompt: |
  Write `func mostFrequent<T: Hashable>(_ items: [T]) -> T?` that returns the item that appears most often. If several tie, return the one that appears **first** in the array. Return `nil` for an empty array.

  ```swift
  print(mostFrequent(["b", "a", "b", "a", "c"]) ?? "none")
  print(mostFrequent([3, 1, 1, 3, 3]) ?? -1)
  print(mostFrequent([Int]()) ?? -1)
  ```

  ```output
  b
  3
  -1
  ```
starter: |
  func mostFrequent<T: Hashable>(_ items: [T]) -> T? {
      // your code
  }
hints:
  - "Count with a [T: Int] dictionary. That's why T must be Hashable."
  - "Dictionary order isn't stable. To break ties by first appearance, walk the original array a second time."
  - "Only replace the best item when a count is strictly greater."
rubric:
  - The only constraint is Hashable.
  - Counts occurrences in a dictionary keyed by T.
  - Ties go to the first item in the array, not to dictionary order.
  - Returns nil for an empty array.
solution: |
  ```swift
  func mostFrequent<T: Hashable>(_ items: [T]) -> T? {
      var counts: [T: Int] = [:]
      for item in items {
          counts[item, default: 0] += 1
      }

      var best: T? = nil
      var bestCount = 0
      for item in items {
          let count = counts[item, default: 0]
          if count > bestCount {
              best = item
              bestCount = count
          }
      }
      return best
  }

  print(mostFrequent(["b", "a", "b", "a", "c"]) ?? "none")
  print(mostFrequent([3, 1, 1, 3, 3]) ?? -1)
  print(mostFrequent([Int]()) ?? -1)
  ```

  ```output
  b
  3
  -1
  ```

  `Hashable` is the one constraint the body needs: dictionary keys require it (`Dictionary<Key, Value> where Key: Hashable`). No `Comparable`, because nothing is ordered.

  The second loop walks the original array, not the dictionary. A dictionary's iteration order isn't defined, so picking the winner from `counts` directly could return `"a"` on one run and `"b"` on another. Using `>` instead of `>=` keeps the first item that reached the top count. For an empty array neither loop runs and `best` stays `nil`.
````

````exercise
id: m11-l03-e6
type: explain
prompt: |
  A teammate wrote this to give `Stack` equality, and it compiles. Then `[Stack<Int>]().contains(Stack<Int>())` and `func f<T: Equatable>(_ x: T)` called as `f(Stack<Int>())` both fail. Explain why in two or three sentences, and give the one-line fix.
code: |
  struct Stack<Element> {
      var items: [Element] = []
  }

  extension Stack where Element: Equatable {
      static func == (lhs: Stack, rhs: Stack) -> Bool {
          lhs.items == rhs.items
      }
  }
rubric:
  - Says the extension adds an == function but no Equatable conformance.
  - Says contains(_:) and the generic function require Equatable conformance, not just an == operator.
  - "Gives extension Stack: Equatable where Element: Equatable {} as the fix."
solution: |
  The constrained extension gives `Stack<Int>` an `==` operator, but it never says `Stack` **conforms** to `Equatable`. `contains(_:)` and `f<T: Equatable>` check for the conformance, not for a function that happens to be named `==`, so they reject it. Protocols in Swift are opt-in by declaration, not by shape.

  The fix is a conditional conformance, and Swift will even write `==` for you:

  ```swift
  struct Stack<Element> {
      var items: [Element] = []
  }

  extension Stack: Equatable where Element: Equatable {}

  func f<T: Equatable>(_ x: T) -> Bool {
      x == x
  }

  print([Stack<Int>()].contains(Stack<Int>()))
  print(f(Stack(items: [1])))
  ```

  ```output
  true
  true
  ```
````

## Summary

- `<T: Protocol>` limits which types callers can pass and lets the body use the protocol's requirements. Ask for the weakest constraint the body needs.
- Combine constraints with `&`; give each type parameter its own constraints.
- A `where` clause can hold any constraint, including same-type requirements like `First.Element == Second.Element`, which the angle brackets can't express.
- A constrained extension (`extension Stack where Element: Numeric`) adds members to some specializations only. `sorted()`, `max()` and `contains(_:)` come from extensions like these.
- A conditional conformance (`extension Stack: Equatable where Element: Equatable`, Swift 4.1) makes the type itself conform, so it works wherever the protocol is required. `Array`'s `Equatable` and `Hashable` work this way.
- Associated types take constraints in the protocol (`associatedtype Item: Hashable`) or in a generic function's `where` clause (`where C.Item: Equatable`).
- Primary associated types (Swift 5.7) let you write `some Collection<Int>`, `any Collection<Int>`, and `protocol Container<Item>` for your own protocols.
