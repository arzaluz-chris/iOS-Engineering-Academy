---
id: m11-l01
title: Generic functions
description: You replace near-identical copies of a function with one generic function, read the <T> syntax, see how Swift picks T at each call, use several type parameters, and connect the some parameters from Module 10 to the generics they abbreviate.
module: m11
order: 1
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m10-l06]
objectives:
  - Spot functions that differ only in the types they work with and merge them into one generic function.
  - Declare a generic function with a type parameter in angle brackets and use that parameter in the signature and body.
  - Explain how Swift infers the type parameter at each call site and what to do when it can't.
  - Write a generic function with two independent type parameters.
  - Rewrite a some parameter as a named generic parameter and say when you need the named form.
terms:
  - term: Generic function
    definition: "A function with one or more type parameters, like func repeated<T>(_ value: T, times: Int) -> [T]. The body is written once and works for every type the caller uses."
  - term: Type parameter
    definition: "A placeholder name for a type, declared in angle brackets after the function name (<T>, <Element>). Each call replaces it with one concrete type."
  - term: Type inference at the call site
    definition: "Swift works out the concrete type for each type parameter from the arguments, or from the type the result is assigned to. You never write repeated<Int>(…) for a function."
  - term: Placeholder name conventions
    definition: "Single letters like T, U for short, generic helpers; descriptive UpperCamelCase names like Element, Key, Value when the parameter has a clear role."
mastery:
  - Turn two functions that differ only in a type into one generic function and call it with both types.
  - Read "conflicting arguments to generic parameter 'T'" and say which arguments disagree.
  - "Fix \"generic parameter 'T' could not be inferred\" by giving the result a type annotation."
  - Write a generic function with two type parameters, like a pair transformer.
  - "Rewrite func f(_ x: some P) as func f<T: P>(_ x: T), and give one case where only the named form works."
resources: [swift-book-generics, swift-book-functions, swift-book-opaque-types]
cards:
  - id: m11-l01-c1
    front: "What does the <T> in func repeated<T>(_ value: T, times: Int) -> [T] declare?"
    back: "A type parameter named T. Each call fixes T to one concrete type: repeated(\"a\", times: 2) makes T String and returns [String]."
  - id: m11-l01-c2
    front: "Why doesn't largest(3, \"three\") compile when the function is <T: Comparable>(_ a: T, _ b: T)?"
    back: "Both parameters use the same T, so both arguments must be the same type. Int and String conflict: \"conflicting arguments to generic parameter 'T'\"."
  - id: m11-l01-c3
    front: "How do you call func makeEmpty<T>() -> [T] when T appears only in the return type?"
    back: "Give the result a type: let names: [String] = makeEmpty(). Swift can't infer T from arguments, and you can't write makeEmpty<String>() for a function."
  - id: m11-l01-c4
    front: "func show(_ value: some CustomStringConvertible) is shorthand for what?"
    back: "func show<T: CustomStringConvertible>(_ value: T). You need the named form when two parameters must share a type or the return type must mention it."
---

## The idea in one sentence

A **generic function** is written once with a placeholder type, `T`, and Swift fills in the real type at every call, so you get one function that works for `Int`, `String` and your own structs without losing any type checking.

## The duplication problem

Say you need a function that builds an array by repeating a value. You write it for `Int`, and a week later you need it for `String`:

```swift
func repeatedInts(_ value: Int, times: Int) -> [Int] {
    var result: [Int] = []
    for _ in 0..<times {
        result.append(value)
    }
    return result
}

func repeatedStrings(_ value: String, times: Int) -> [String] {
    var result: [String] = []
    for _ in 0..<times {
        result.append(value)
    }
    return result
}

print(repeatedInts(0, times: 3))
print(repeatedStrings("ab", times: 2))
```

```output
[0, 0, 0]
["ab", "ab"]
```

The two bodies are character-for-character identical except for the type. The logic doesn't care what the value is: it only stores it and appends it. A third copy for `Double` and a fourth for your `Book` struct would be the same again. Copies drift: fix a bug in one and you'll forget the others.

You've met one escape hatch already, in `print`'s signature: `Any`. A function taking `Any` and returning `[Any]` would accept everything, but the caller gets back `[Any]` and has lost the fact that it put `Int`s in. Every use would need a cast. Generics keep the type.

## One function with a type parameter

```swift
func repeated<T>(_ value: T, times: Int) -> [T] {
    var result: [T] = []
    for _ in 0..<times {
        result.append(value)
    }
    return result
}

let zeros = repeated(0, times: 3)
let words = repeated("ab", times: 2)
let flags = repeated(true, times: 1)
print(zeros)
print(words)
print(flags)
print(zeros.count + words.count)
```

```output
[0, 0, 0]
["ab", "ab"]
[true]
5
```

Line by line:

1. `<T>` after the function name declares a **type parameter** called `T`. It's a name for "some type the caller will choose". It isn't a real type, and it isn't `Any`.
2. `_ value: T` says the parameter has that type. `-> [T]` says the result is an array of that same type.
3. Inside the body, `T` works like any type name: `var result: [T] = []`.
4. `repeated(0, times: 3)`: the argument is an `Int`, so for this call `T` is `Int` and the result is `[Int]`. `zeros` is a plain `[Int]`, not `[Any]`.
5. `repeated("ab", times: 2)`: here `T` is `String`. Same function, different `T`.
6. `zeros.count + words.count` compiles because each result has its real type.

The name `T` is a convention for "type". You can pick any UpperCamelCase name, and a descriptive one is better when the parameter has a role: the standard library uses `Element`, `Key`, `Value`, `Wrapped`. Single letters are fine for short helpers where the type has no meaning beyond "whatever you pass".

## How Swift picks T

You never write the type yourself at the call. Swift **infers** `T` from the arguments, the same way it infers `let x = 5` is an `Int`. Each call is checked separately, and inside one call `T` means exactly one type.

That's why this fails:

```swift no-compile conflicting arguments to generic parameter 'T'
func firstOfTwo<T>(_ a: T, _ b: T) -> T {
    a
}

let first = firstOfTwo(1, "one")
```

Swift 6.3: `error: conflicting arguments to generic parameter 'T' ('String' vs. 'Int')`. Both parameters say `T`, so they must be the same type, and one argument says `Int` while the other says `String`. That's a feature: the signature promises the two values have the same type, and the compiler holds every caller to it. Compare the two `some Equatable` parameters in Module 10, which could be different types. A shared named parameter is how you say "the same type".

> [!warning] Inside print, T can quietly become Any
> `print(firstOfTwo(1, "one"))` compiles and prints `1`. `print` accepts `Any`, so Swift finds a type that both arguments fit, `Any`, and uses it for `T`. Assigning the result to a constant first, as above, takes that escape away. Once `T` has a constraint like `Equatable` (lesson 3), `Any` no longer qualifies and the call fails even inside `print`.

When `T` appears only in the return type, there's nothing to infer it from:

```swift no-compile generic parameter 'T' could not be inferred
func makeEmpty<T>() -> [T] {
    []
}

let nothing = makeEmpty()
```

Give the result a type and Swift works backward from it:

```swift
func makeEmpty<T>() -> [T] {
    []
}

let names: [String] = makeEmpty()
let scores = makeEmpty() as [Int]
print(names, scores)
print(type(of: names))
```

```output
[] []
Array<String>
```

You might expect `makeEmpty<String>()` to work, as it does for types (`Array<String>`). For functions, Swift 6.3 says `error: cannot explicitly specialize global function 'makeEmpty()'`. Annotate the result instead.

## What you can do with a T

Inside a generic function you only know that `T` is *some* type, so you can only do what works for every type: store it, pass it along, return it, put it in an array, interpolate it into a string. You can't compare two `T`s with `>` or add them with `+`, because some types don't support that:

```swift no-compile requires that 'T' conform to 'Comparable'
func larger<T>(_ a: T, _ b: T) -> T {
    a > b ? a : b
}
```

Swift 6.3: `error: referencing operator function '>' on 'Comparable' requires that 'T' conform to 'Comparable'`. The fix is a **constraint**, `<T: Comparable>`, which limits `T` to types that support `<` and `>`. That's lesson 3. For now, notice that it's the compiler protecting you: if `larger` compiled, someone could call it with two `Book` structs that have no ordering.

Functions you pass in are the other way to do real work with a `T`. The caller knows the concrete type, so the caller supplies the logic:

```swift
func firstMatch<T>(in items: [T], where test: (T) -> Bool) -> T? {
    for item in items {
        if test(item) {
            return item
        }
    }
    return nil
}

let prices = [12, 48, 7, 99]
let names = ["Ana", "Bo", "Cecilia"]

print(firstMatch(in: prices) { price in price > 40 } ?? -1)
print(firstMatch(in: names) { name in name.count > 5 } ?? "none")
print(firstMatch(in: names) { name in name.hasPrefix("Z") } ?? "none")
```

```output
48
Cecilia
none
```

`firstMatch` never compares items itself. It walks the array and asks `test`. In the first call `T` is `Int`, so `test` has type `(Int) -> Bool` and the closure can use `>`. In the second, `T` is `String` and the closure can use `count`. The result is `T?`: `Int?` or `String?`, which is why `??` needs a default of the matching type. This is the shape of the standard library's `first(where:)`, which you used in Module 7.

## Several type parameters

A function can declare more than one type parameter, separated by commas. Each is inferred on its own and they can be different types:

```swift
func mapPair<Input, Output>(_ pair: (Input, Input), _ transform: (Input) -> Output) -> (Output, Output) {
    (transform(pair.0), transform(pair.1))
}

let lengths = mapPair(("swift", "generics")) { word in word.count }
let doubled = mapPair((3, 4)) { n in n * 2 }
let labels = mapPair((1, 2)) { n in "#\(n)" }
print(lengths)
print(doubled)
print(labels)
```

```output
(5, 8)
(6, 8)
("#1", "#2")
```

- In the first call `Input` is `String` and `Output` is `Int`, inferred from the tuple and from what the closure returns.
- In the second, both are `Int`. Two type parameters **can** be the same type; they just don't have to be.
- In the third, `Input` is `Int` and `Output` is `String`.

Use separate parameters when the types are independent and the same parameter when they must match. That choice is the whole design of a generic signature.

## some parameters are generics in disguise

Module 10 showed `some` in parameter position and promised this lesson would explain it. Since Swift 5.7 (SE-0341), these two declarations mean the same thing:

```swift
func shout(_ value: some CustomStringConvertible) -> String {
    value.description.uppercased() + "!"
}

func whisper<T: CustomStringConvertible>(_ value: T) -> String {
    value.description.lowercased() + "..."
}

print(shout("hello"))
print(shout(42))
print(whisper("HELLO"))
print(whisper(true))
```

```output
HELLO!
42!
hello...
true...
```

`some CustomStringConvertible` is an **anonymous** type parameter with a constraint. `<T: CustomStringConvertible>` names it. The compiler treats both the same way: each call fixes the type, and it can specialize the function for it.

The `some` form is shorter and reads well when the type is used once. You need the named form when:

- **Two parameters must be the same type.** `func same(_ a: some Equatable, _ b: some Equatable)` gives you two independent types. `func same<T: Equatable>(_ a: T, _ b: T)` gives you one.
- **The return type mentions it.** `repeated` returns `[T]`; there's no way to say "an array of whatever the parameter was" with `some`.
- **There's no constraint.** `some` needs a protocol after it. `<T>` alone is fine.

## A practical example: splitting work into batches

Apps often send data to a server in batches: 50 photos at a time, 100 log lines at a time. The splitting logic doesn't care what's in the batch:

```swift
func batches<T>(of items: [T], size: Int) -> [[T]] {
    guard size > 0 else {
        return [items]
    }
    var result: [[T]] = []
    var current: [T] = []
    for item in items {
        current.append(item)
        if current.count == size {
            result.append(current)
            current = []
        }
    }
    if !current.isEmpty {
        result.append(current)
    }
    return result
}

struct Photo {
    let name: String
}

let photos = [Photo(name: "a.jpg"), Photo(name: "b.jpg"), Photo(name: "c.jpg")]
for batch in batches(of: photos, size: 2) {
    print(batch.map { photo in photo.name })
}

print(batches(of: Array(1...7), size: 3))
print(batches(of: ["x"], size: 0))
```

```output
["a.jpg", "b.jpg"]
["c.jpg"]
[[1, 2, 3], [4, 5, 6], [7]]
[["x"]]
```

The same function batches your own `Photo` struct and plain `Int`s. Each batch comes back with its real element type, so `batch.map { photo in photo.name }` compiles without a cast. The `guard` handles a size of zero, which would otherwise never fill a batch.

## Common mistakes

> [!error] error: conflicting arguments to generic parameter 'T'
> Two parameters share `T`, and the call passes different types for them. Either the call is wrong (convert one argument), or the function should have two type parameters, `<A, B>`.

> [!error] error: generic parameter 'T' could not be inferred
> `T` appears only in the return type, or nowhere Swift can see from the arguments. Annotate the result: `let names: [String] = makeEmpty()`.

> [!error] error: cannot explicitly specialize global function
> `makeEmpty<String>()` isn't allowed for functions in Swift 6.3. Angle brackets after a name work for types, not function calls. Annotate the result instead.

> [!error] error: referencing operator function '>' on 'Comparable' requires that 'T' conform to 'Comparable'
> An unconstrained `T` can't be compared, added or printed with any special formatting. Add a constraint (lesson 3), or take a closure that does the type-specific work.

> [!error] Reaching for Any instead of a generic
> `func repeated(_ value: Any, times: Int) -> [Any]` compiles, but callers get `[Any]` back and have to cast. If the output type follows from the input type, that's a generic.

> [!error] error: generic parameter 'T' is not used in function signature
> `func noop<T>(_ x: Int) -> Int` declares a `T` that nothing uses, so no call could ever decide it. Remove it.

````exercise
id: m11-l01-e1
type: comprehension
prompt: "Given `func repeated<T>(_ value: T, times: Int) -> [T]`, what's the type of `let result = repeated(2.5, times: 2)`?"
choices:
  - text: "[T]"
    correct: false
    why: "T is a placeholder in the declaration. At a call, it's replaced by a concrete type."
  - text: "[Any]"
    correct: false
    why: "That's what you'd get with an Any-based function. A generic keeps the real type."
  - text: "[Double]"
    correct: true
    why: "2.5 is a Double literal, so for this call T is Double and the result is [Double]."
  - text: "It doesn't compile; you must write repeated<Double>(2.5, times: 2)."
    correct: false
    why: "Swift infers T from the argument, and explicit specialization of a function isn't allowed anyway."
solution: |
  **`[Double]`.** Swift infers `T` from the argument at each call. A floating-point literal defaults to `Double`, so `T` is `Double` and the return type `[T]` becomes `[Double]`. Nothing about the result is erased: you could write `result[0] * 2` without a cast.
````

````exercise
id: m11-l01-e2
type: prediction
prompt: Predict the exact output.
code: |
  func swapped<A, B>(_ pair: (A, B)) -> (B, A) {
      (pair.1, pair.0)
  }

  func twice<T>(_ value: T) -> [T] {
      [value, value]
  }

  let flipped = swapped((1, "one"))
  print(flipped)
  print(swapped(flipped))
  print(twice(flipped.0))
  print(twice(twice(3)))
output: |
  ("one", 1)
  (1, "one")
  ["one", "one"]
  [[3, 3], [3, 3]]
hints:
  - "In the first call A is Int and B is String, so the result is (String, Int)."
  - "twice(twice(3)): the inner call makes T Int; the outer call makes T [Int]."
solution: |
  ```output
  ("one", 1)
  (1, "one")
  ["one", "one"]
  [[3, 3], [3, 3]]
  ```

  1. `swapped((1, "one"))`: `A` is `Int`, `B` is `String`, the result has type `(String, Int)`.
  2. `swapped(flipped)`: now `A` is `String` and `B` is `Int`. Same function, the parameters swapped roles, and you get the original back.
  3. `flipped.0` is `"one"`, so `twice` makes `T` `String`.
  4. The inner `twice(3)` returns `[3, 3]` with `T` as `Int`. The outer call receives an `[Int]`, so there `T` is `[Int]`, and it returns an array of two arrays. A type parameter can be any type, including an array.
````

````exercise
id: m11-l01-e3
type: fill-in
prompt: |
  Complete the generic function so it returns the last element of an array, or `fallback` when the array is empty. It has to work for any element type.
code: |
  func lastOrDefault[[1]](_ items: [[[2]]], fallback: T) -> [[3]] {
      items.last ?? fallback
  }

  print(lastOrDefault([3, 5, 9], fallback: 0))
  print(lastOrDefault([String](), fallback: "empty"))
blanks:
  - id: "1"
    answers: ["<T>"]
  - id: "2"
    answers: ["T"]
  - id: "3"
    answers: ["T"]
solution: |
  ```swift
  func lastOrDefault<T>(_ items: [T], fallback: T) -> T {
      items.last ?? fallback
  }

  print(lastOrDefault([3, 5, 9], fallback: 0))
  print(lastOrDefault([String](), fallback: "empty"))
  ```

  ```output
  9
  empty
  ```

  `<T>` declares the type parameter. The array holds `T`s, the fallback is a `T`, and the result is a `T`: one type for all three, which is what makes `items.last ?? fallback` type-check (`items.last` is `T?`). `[String]()` is an empty array whose element type is spelled out, so Swift can infer `T` as `String`.
````

````exercise
id: m11-l01-e4
type: find-errors
prompt: Which lines have real problems?
code: |
  func pair<T>(_ a: T, _ b: T) -> [T] {
      [a, b]
  }

  func biggest<T>(_ items: [T]) -> T? {
      var best = items.first
      for item in items where item > best! {
          best = item
      }
      return best
  }

  func makeList<T>() -> [T] {
      []
  }

  let mixed = pair(1, "two")
  let list = makeList()
  let numbers = pair(1, 2)
choices:
  - text: "pair(1, \"two\") passes an Int and a String for the same T."
    correct: true
    why: "Swift 6.3 reports conflicting arguments to generic parameter 'T'."
  - text: "biggest compares two T values with > but T has no constraint."
    correct: true
    why: "An unconstrained T doesn't support >. It needs T: Comparable."
  - text: "makeList() gives Swift nothing to infer T from."
    correct: true
    why: "T appears only in the return type, and the result has no annotation."
  - text: "pair(1, 2) is a problem because T can't be inferred from literals."
    correct: false
    why: "Both literals are Int, so T is Int and the result is [Int]."
rubric:
  - Identifies the conflicting arguments in pair(1, "two").
  - Identifies the missing Comparable constraint in biggest.
  - Identifies the uninferable T in makeList().
  - Doesn't flag pair(1, 2).
solution: |
  Three real problems:

  1. `pair(1, "two")` gives `T` two different types. Make both arguments the same type, or declare `<A, B>` if the function really should accept two types (and then it can't return `[T]`).
  2. `biggest` uses `>` on an unconstrained `T`. You'll write `<T: Comparable>` in lesson 3. (The force unwrap `best!` is also a smell, but it isn't what stops the code compiling.)
  3. `makeList()` has nothing to infer `T` from. Write `let list: [String] = makeList()`.

  `pair(1, 2)` is fine: `T` is `Int`.
````

````exercise
id: m11-l01-e5
type: solve
prompt: |
  Write a generic function `interleave(_:_:)` that takes two arrays of the **same** element type and returns one array that alternates between them, starting with the first. When one array runs out, append the rest of the other.

  ```swift
  print(interleave([1, 3, 5, 7], [2, 4]))
  print(interleave(["a"], ["b", "c", "d"]))
  print(interleave([Int](), [9]))
  ```

  ```output
  [1, 2, 3, 4, 5, 7]
  ["a", "b", "c", "d"]
  [9]
  ```
starter: |
  func interleave<T>(_ first: [T], _ second: [T]) -> [T] {
      // your code
  }
hints:
  - "Loop over indexes from 0 up to the larger count."
  - "At each index, append first[i] if i is a valid index of first, then second[i] if it's valid for second."
rubric:
  - Uses one type parameter for both arrays and the result.
  - Handles arrays of different lengths, including an empty one.
  - Never reads past the end of either array.
  - The output matches exactly.
solution: |
  ```swift
  func interleave<T>(_ first: [T], _ second: [T]) -> [T] {
      var result: [T] = []
      let longest = max(first.count, second.count)
      for index in 0..<longest {
          if index < first.count {
              result.append(first[index])
          }
          if index < second.count {
              result.append(second[index])
          }
      }
      return result
  }

  print(interleave([1, 3, 5, 7], [2, 4]))
  print(interleave(["a"], ["b", "c", "d"]))
  print(interleave([Int](), [9]))
  ```

  ```output
  [1, 2, 3, 4, 5, 7]
  ["a", "b", "c", "d"]
  [9]
  ```

  One `T` covers both inputs and the output, so the signature itself says "two arrays of the same kind in, one array of that kind out". The loop runs to the longer count, and the two `if`s check bounds before each read, which handles the uneven tails and the empty array without special cases. `0..<0` is an empty range, so two empty arrays would return `[]`.
````

````exercise
id: m11-l01-e6
type: refactor
prompt: |
  These three functions do the same thing for different types. Replace them with one generic function and keep all three calls working with the same output.
code: |
  func countMatchingInts(_ items: [Int], _ test: (Int) -> Bool) -> Int {
      var count = 0
      for item in items where test(item) { count += 1 }
      return count
  }

  func countMatchingStrings(_ items: [String], _ test: (String) -> Bool) -> Int {
      var count = 0
      for item in items where test(item) { count += 1 }
      return count
  }

  func countMatchingDoubles(_ items: [Double], _ test: (Double) -> Bool) -> Int {
      var count = 0
      for item in items where test(item) { count += 1 }
      return count
  }

  print(countMatchingInts([1, 8, 12]) { n in n > 5 })
  print(countMatchingStrings(["hi", "hello"]) { s in s.count > 2 })
  print(countMatchingDoubles([0.5, 1.5]) { d in d < 1 })
rubric:
  - One function with a type parameter replaces all three.
  - The array and the closure parameter use the same type parameter.
  - The return type stays Int, not T.
  - All three calls compile and print 2, 1, 1.
solution: |
  ```swift
  func countMatching<T>(_ items: [T], _ test: (T) -> Bool) -> Int {
      var count = 0
      for item in items where test(item) {
          count += 1
      }
      return count
  }

  print(countMatching([1, 8, 12]) { n in n > 5 })
  print(countMatching(["hi", "hello"]) { s in s.count > 2 })
  print(countMatching([0.5, 1.5]) { d in d < 1 })
  ```

  ```output
  2
  1
  1
  ```

  The only thing that changed between the three versions was the element type, and it appeared in exactly two places: the array and the closure's parameter. Both become `T`, which also ties them together: the closure always receives the type the array holds. The return type is a count, so it stays `Int`. Not everything in a generic function has to be generic.
````

## Summary

- When functions differ only in the types they handle, write one generic function: `func name<T>(…)`.
- `T` is a type parameter. Each call fixes it to one concrete type, inferred from the arguments or from the result's annotation. You can't write `name<Int>(…)` for a function.
- Parameters that share `T` must receive the same type at a call; use separate parameters (`<A, B>`) for independent types.
- An unconstrained `T` only supports what every type supports. Pass a closure for type-specific work, or add a constraint (lesson 3).
- `some P` in a parameter is an anonymous generic parameter (SE-0341). Use the named form when two parameters must match, the return type needs it, or there's no protocol.
- Generics beat `Any` because the caller gets the real type back, with no casts.
