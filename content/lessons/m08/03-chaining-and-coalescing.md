---
id: m08-l03
title: "Optional chaining and nil-coalescing"
description: You use ?? precisely, including when its right side runs and how its precedence can surprise you, call methods and properties through an optional with ?., and combine the two to turn a chain of maybes into one plain value.
module: m08
order: 3
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m08-l02]
objectives:
  - Explain exactly what a ?? b produces and when b is evaluated.
  - Chain several ?? operators and predict the type of the result.
  - Call a method or read a property through an optional with ?. and explain why the result is always optional.
  - Build multi-step chains like words?.first?.count and know when each ? is needed.
  - Combine optional chaining with ?? or if let to get a plain value out.
terms:
  - term: Nil-coalescing operator (??)
    definition: "a ?? b gives the value inside a if a holds one, otherwise b. b is only evaluated when a is nil."
  - term: Optional chaining
    definition: "Writing ?. after an optional to read a property or call a method on the value inside it. If the optional is nil, the whole chain stops and produces nil."
  - term: Short-circuit evaluation
    definition: "Skipping the rest of an expression as soon as its result is known. ?? skips its right side when the left has a value; a chain skips everything after a nil."
mastery:
  - Predict the output of an expression where ?? has a function call with a print on its right side.
  - Predict the value and type of a ?? b ?? c when b is optional and c isn't.
  - Explain why a ?? 0 + 1 doesn't add 1 to the unwrapped value.
  - Write a chain like list?.first?.uppercased() and say what type it has.
  - Turn an optional chain into a plain value with ?? or if let.
resources: [swift-book-basics, swift-book-basic-operators, swift-book-collection-types]
cards:
  - id: m08-l03-c1
    front: "In `a ?? b`, when is `b` evaluated?"
    back: Only when a is nil. If a holds a value, b never runs, even if it's a function call.
  - id: m08-l03-c2
    front: "What's the type of `nickname?.count` when nickname is a String?"
    back: "Int?. A chain through an optional always produces an optional, because the chain might have stopped at nil."
  - id: m08-l03-c3
    front: "Why does `words?.first?.count` need two question marks?"
    back: "words is optional, so ?. is needed to reach first. first is itself optional (the array may be empty), so ?. is needed again to reach count."
  - id: m08-l03-c4
    front: "What does `score ?? 0 + 10` compute?"
    back: "score ?? (0 + 10). + binds tighter than ??, so the 10 is only added to the default. Write (score ?? 0) + 10 to add it to the result."
---

## The idea in one sentence

`??` swaps a `nil` for a default value, and `?.` lets you keep working with the value inside an optional, stopping safely at the first `nil`.

## ?? precisely

You've used `??` since Module 4. Here's the precise version.

`a ?? b` takes an optional `a` and a value `b` of the wrapped type. If `a` holds a value, the result is that value, unwrapped. If `a` is `nil`, the result is `b`. When `b` is a plain value, the result is a plain value too: `Int("7") ?? 0` is an `Int`.

The part that's easy to miss: **`b` is only evaluated when it's needed**.

```swift
func fallbackName() -> String {
    print("  (computing the fallback)")
    return "Guest"
}

let savedName: String? = "Ana"
let missingName: String? = nil

print("Hello, \(savedName ?? fallbackName())")
print("Hello, \(missingName ?? fallbackName())")
```

```output
Hello, Ana
  (computing the fallback)
Hello, Guest
```

On the first line `savedName` holds `"Ana"`, so `fallbackName()` is never called: there's no `(computing the fallback)` before `Hello, Ana`. On the second line `missingName` is `nil`, so the function runs and its result is used. This is **short-circuit evaluation**, the same thing `&&` and `||` do. It means an expensive default, like reading a file or doing a long calculation, costs nothing when the optional already has a value. (Swift implements this with a feature called an autoclosure, which you'll meet in Module 11.)

### Chaining ??

`??` can be chained, and it groups from the right: `a ?? b ?? c` means `a ?? (b ?? c)`. Read it as "the first one that has a value":

```swift
let typedName: String? = nil
let savedName: String? = "Sam"

let displayName = typedName ?? savedName ?? "Guest"
print(displayName)

let maybeName = typedName ?? savedName
if let maybeName {
    print("Found \(maybeName)")
}
```

```output
Sam
Found Sam
```

The type of the result depends on the **last** value. `typedName ?? savedName ?? "Guest"` ends in a plain `String`, so it's a `String`. `typedName ?? savedName` ends in an optional, so it's still a `String?`: both could be `nil`, and nothing supplied a guaranteed value.

### ?? and precedence

`??` has a **lower** precedence than arithmetic. That bites:

```swift
let bonus: Int? = 5

print(bonus ?? 0 + 10)
print((bonus ?? 0) + 10)
```

```output
5
15
```

`bonus ?? 0 + 10` is read as `bonus ?? (0 + 10)`: the `+ 10` belongs to the default. Since `bonus` holds 5, the result is 5. If you mean "the bonus, or 0, plus 10", write the parentheses. The rule from Module 4 applies: if you have to think about precedence, add parentheses.

## Optional chaining

Suppose you have an optional `String` and want it uppercased. You can't call `.uppercased()` on a `String?` directly. Swift 6.3:

```swift no-compile value of optional type 'String?' must be unwrapped to refer to member 'uppercased' of wrapped base type 'String'
let nickname: String? = "swiftie"
print(nickname.uppercased())
```

`if let` would work, but it takes three lines for one call. **Optional chaining** does it inline: put `?` before the dot.

```swift
let nickname: String? = "swiftie"
let noNickname: String? = nil

let loud = nickname?.uppercased()
let quiet = noNickname?.uppercased()

print(loud ?? "none")
print(quiet ?? "none")
print(nickname?.count ?? 0)
print(noNickname?.count ?? 0)
```

```output
SWIFTIE
none
7
0
```

1. `nickname?.uppercased()`: `nickname` holds `"swiftie"`, so Swift calls `uppercased()` on the `String` inside. (`uppercased()`, from Module 7, returns a copy of the string in capital letters.)
2. `noNickname?.uppercased()`: `noNickname` is `nil`, so Swift **doesn't call** `uppercased()` at all. The expression is `nil`.
3. Both `loud` and `quiet` are `String?`, even though `uppercased()` returns a plain `String`. They have to be: the chain might stop at `nil`, and then there's no string to return.
4. `nickname?.count` reads a property through the optional. `count` is an `Int`, so the chain is an `Int?`, and `?? 0` turns it into an `Int`.

That third point is the rule of optional chaining: **the result of a chain is always optional**. If the last step returns `Int`, the chain returns `Int?`. If it already returns an optional, the chain doesn't add a second layer: it stays `Int?`.

### Longer chains

Each step that can be `nil` gets its own `?`:

```swift
let recentSearches: [String]? = ["kiwi", "apple"]
let noHistory: [String]? = nil
let emptyHistory: [String]? = []

print(recentSearches?.first?.uppercased() ?? "nothing")
print(noHistory?.first?.uppercased() ?? "nothing")
print(emptyHistory?.first?.uppercased() ?? "nothing")
print(recentSearches?.count ?? 0)
```

```output
KIWI
nothing
nothing
2
```

Read `recentSearches?.first?.uppercased()` from left to right:

1. `recentSearches?`: the array might not exist. If it's `nil`, stop.
2. `.first?`: the array might be empty, so `first` is a `String?`. If it's `nil`, stop.
3. `.uppercased()`: reached only when there's a real `String`.

`noHistory` stops at step 1. `emptyHistory` gets past step 1 (it's a real, empty array) and stops at step 2. Both produce `nil`, and `??` supplies `"nothing"`. The `?` after `count`'s chain isn't needed because `count` isn't optional: an array that exists always has a count.

You can't put `?` after something that isn't optional. Swift 6.3:

```swift no-compile cannot use optional chaining on non-optional value of type 'String'
let city = "Lima"
print(city?.uppercased() ?? "")
```

## Getting a plain value out of a chain

A chain gives you an optional. To use it, finish with one of the tools you already have:

```swift
let tags: [String]? = ["swift", "ios"]

let firstTagLength = tags?.first?.count ?? 0
print(firstTagLength)

if let firstTag = tags?.first {
    print("First tag: \(firstTag)")
}

if tags?.isEmpty == false {
    print("There are tags")
}
```

```output
5
First tag: swift
There are tags
```

- `?? default` when there's a sensible default.
- `if let` (or `guard let`) when you need different code for the missing case.
- Comparing with `== true` or `== false` when the chain ends in a `Bool`. `tags?.isEmpty` is a `Bool?`, and an `if` needs a real `Bool`, so `if tags?.isEmpty { … }` doesn't compile. `== false` is true only when the array exists **and** isn't empty; when `tags` is `nil`, `nil == false` is `false`.

## A practical example: a profile header

A user profile where every field is optional, as data from a server often is:

```swift
func header(name: String?, city: String?, interests: [String]?) -> String {
    let displayName = name?.uppercased() ?? "ANONYMOUS"
    let place = city ?? "somewhere"
    let interestCount = interests?.count ?? 0
    let topInterest = interests?.first ?? "nothing yet"
    return "\(displayName) from \(place), \(interestCount) interests, top: \(topInterest)"
}

print(header(name: "Christian", city: "Lima", interests: ["iOS", "running"]))
print(header(name: nil, city: nil, interests: nil))
print(header(name: "Ana", city: nil, interests: []))
```

```output
CHRISTIAN from Lima, 2 interests, top: iOS
ANONYMOUS from somewhere, 0 interests, top: nothing yet
ANA from somewhere, 0 interests, top: nothing yet
```

Every line of the function takes an optional and produces a plain value. After those four lines, the rest of the function, here just the `return`, never touches an optional. That's the pattern to aim for: deal with the optionals at the edge, then work with plain values.

## Common mistakes

> [!error] error: value of optional type 'String?' must be unwrapped to refer to member 'uppercased' of wrapped base type 'String'
> You called a method on an optional with a plain `.`. Use `?.` (and handle the optional result), or unwrap first with `if let`.

> [!error] error: cannot use optional chaining on non-optional value of type 'String'
> You wrote `?.` on a value that can't be `nil`. Use a plain `.`.

> [!error] error: binary operator '??' cannot be applied to operands of type 'Int?' and 'String'
> The default must have the wrapped type. `Int("x") ?? "none"` mixes `Int` and `String`. Pick a default of the right type, or convert first. Swift 6.3:

```swift no-compile binary operator '??' cannot be applied to operands of type 'Int?' and 'String'
let quantity = Int("x") ?? "none"
```

> [!error] Forgetting that a chain's result is optional
> `let length: Int = name?.count` doesn't compile: the chain is an `Int?`. Finish it with `?? 0` or bind it with `if let`.

> [!error] Arithmetic on the wrong side of ??
> `price ?? 0 * quantity` multiplies the default, not the price. Write `(price ?? 0) * quantity`.

````exercise
id: m08-l03-e1
type: comprehension
prompt: "`list` is a `[String]?`. What's the type of `list?.first?.count`?"
choices:
  - text: "`Int`"
    correct: false
    why: The chain can stop at nil in two places, so the result can't be a plain Int.
  - text: "`Int?`"
    correct: true
    why: A chain is always optional, and Swift doesn't stack a second layer when a step is already optional.
  - text: "`Int??`"
    correct: false
    why: Optional chaining flattens. Whether it stops at list or at first, the result is the same single nil.
  - text: It doesn't compile; first is already optional.
    correct: false
    why: That's why first is followed by ?. to reach count.
solution: |
  **`Int?`**. `count` returns an `Int`; the chain might stop at `list?` or at `first?`, so it wraps the result once, as `Int?`. A chain never produces a nested optional on its own: no matter where it stops, you get one `nil`.
````

````exercise
id: m08-l03-e2
type: prediction
prompt: Predict the exact output.
code: |
  func backupScore() -> Int {
      print("backup used")
      return 50
  }

  let scores: [Int]? = [70, 85]
  let none: [Int]? = nil

  print(scores?.first ?? backupScore())
  print(none?.first ?? backupScore())
  print(scores?.count ?? 0 + 1)
  print((none?.count ?? 0) + 1)
  print(none?.first ?? scores?.last ?? 0)
output: |
  70
  backup used
  50
  2
  1
  85
hints:
  - The right side of ?? only runs when the left side is nil.
  - "+ binds tighter than ??."
  - "a ?? b ?? c is the first one with a value."
solution: |
  ```output
  70
  backup used
  50
  2
  1
  85
  ```

  1. `scores?.first` is 70, so `backupScore()` never runs.
  2. `none?.first` is `nil`, so `backupScore()` runs: it prints its line, then 50 is printed.
  3. `scores?.count ?? 0 + 1` is `scores?.count ?? (0 + 1)`. The count is 2, so the `+ 1` is never used.
  4. With parentheses, `(nil ?? 0) + 1` is 1.
  5. `none?.first` is `nil`, so Swift tries `scores?.last`, which is 85.
````

````exercise
id: m08-l03-e3
type: fill-in
prompt: |
  Complete the code so it prints the number of letters in the first word of the list, or 0 if there's no list or the list is empty. It should print `5` and then `0`.
code: |
  let words: [String]? = ["hello", "world"]
  let noWords: [String]? = nil
  print(words[[1]]first[[2]]count ?? 0)
  print(noWords?.first?.count [[3]] 0)
blanks:
  - id: "1"
    answers: ["?."]
  - id: "2"
    answers: ["?."]
  - id: "3"
    answers: ["??"]
solution: |
  ```swift
  let words: [String]? = ["hello", "world"]
  let noWords: [String]? = nil
  print(words?.first?.count ?? 0)
  print(noWords?.first?.count ?? 0)
  ```

  ```output
  5
  0
  ```

  `words` is optional, so it needs `?.` to reach `first`. `first` is optional too, so it needs `?.` to reach `count`. The chain is an `Int?`, and `?? 0` makes it an `Int` that `print` shows without `Optional(…)` or a warning.
````

````exercise
id: m08-l03-e4
type: refactor
prompt: |
  This function works, but it unwraps everything by hand. Rewrite it with optional chaining and `??` so the body is one or two lines. The output must stay the same.
code: |
  func initial(of name: String?) -> String {
      if let name {
          if let firstLetter = name.first {
              return String(firstLetter).uppercased()
          } else {
              return "?"
          }
      } else {
          return "?"
      }
  }
  print(initial(of: "christian"), initial(of: ""), initial(of: nil))
rubric:
  - The function uses ?. at least twice and ?? once.
  - There's a single "?" default, not one per missing case.
  - The output is still C ? ?.
solution: |
  ```swift
  func initial(of name: String?) -> String {
      let firstLetter = name?.first
      return firstLetter?.uppercased() ?? "?"
  }
  print(initial(of: "christian"), initial(of: ""), initial(of: nil))
  ```

  ```output
  C ? ?
  ```

  `name?.first` is a `Character?`: `nil` when there's no name or the name is empty. `Character` has its own `uppercased()`, which returns a `String`, so the second line chains through it and falls back to `"?"` once, covering both missing cases. The original needed two `else` branches that did the same thing; a chain merges every "stop here" into one `nil`.
````

````exercise
id: m08-l03-e5
type: solve
prompt: |
  Write `func summary(of readings: [Int]?) -> String` that describes a list of temperature readings that might not exist:

  - `"No data"` if `readings` is `nil` or empty,
  - otherwise `"N readings, first F, last L"`.

  Use optional chaining. Check it with:

  ```swift
  print(summary(of: [18, 21, 19]))
  print(summary(of: []))
  print(summary(of: nil))
  ```

  ```output
  3 readings, first 18, last 19
  No data
  No data
  ```
starter: |
  func summary(of readings: [Int]?) -> String {
      // your code
  }
hints:
  - "readings?.first and readings?.last are both Int?."
  - "If first exists, the array exists and isn't empty, so last exists too."
  - "guard let first = readings?.first, let last = readings?.last else { … }"
rubric:
  - I used optional chaining to reach first and last.
  - "nil and [] produce the same message without a separate check for each."
  - The function returns the text; the caller prints it.
  - The output matches exactly.
solution: |
  ```swift
  func summary(of readings: [Int]?) -> String {
      guard let first = readings?.first, let last = readings?.last else {
          return "No data"
      }
      let count = readings?.count ?? 0
      return "\(count) readings, first \(first), last \(last)"
  }

  print(summary(of: [18, 21, 19]))
  print(summary(of: []))
  print(summary(of: nil))
  ```

  ```output
  3 readings, first 18, last 19
  No data
  No data
  ```

  `readings?.first` is `nil` both when there's no array and when the array is empty, so one `guard` handles both. After the guard, `first` and `last` are plain `Int`s. The `?? 0` on the count never actually uses its default (the guard proved the array exists), but `readings` itself is still a `[Int]?` here; another option is to bind it too: `guard let readings, let first = readings.first, …`.
````

````exercise
id: m08-l03-e6
type: explain
prompt: |
  A teammate writes `let total = cachedTotal ?? computeTotalFromServer()` and worries that it contacts the server every time. Explain whether that's true and why.
code: |
  let total = cachedTotal ?? computeTotalFromServer()
rubric:
  - I said the server call only happens when cachedTotal is nil.
  - I explained short-circuit evaluation of the right side of ??.
  - I compared it with && or || or with the prediction example.
solution: |
  It's not true. `??` evaluates its right side **only when the left side is `nil`**. If `cachedTotal` holds a value, `computeTotalFromServer()` is never called, just as `fallbackName()` didn't print anything when `savedName` had a value. It's the same short-circuit behavior as `&&` and `||`, which skip their right side when the left already decides the result. So the line means "use the cache if there is one, and only go to the server if there isn't", which is exactly what a cache should do.
````

## Summary

- `a ?? b` is the value inside `a`, or `b` when `a` is `nil`. `b` is only evaluated when it's needed.
- `a ?? b ?? c` gives the first value that exists. The result is optional unless the last one is a plain value.
- `??` has lower precedence than arithmetic: write `(a ?? 0) + 1`.
- `optional?.member` reaches into an optional. If it's `nil`, the rest of the chain is skipped.
- A chain's result is always optional, never doubly optional. Each step that can be `nil` needs its own `?`.
- Finish a chain with `??`, `if let`/`guard let`, or `== true` for a `Bool?`.
