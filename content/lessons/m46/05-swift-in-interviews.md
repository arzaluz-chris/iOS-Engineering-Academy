---
id: m46-l05
title: Swift quirks in interviews
description: You go through the Swift behaviors that trip people up in coding interviews (String indexing, Character versus Unicode scalars, overflow traps, % with negative numbers, Dictionary subscripts and iteration order, sort versus sorted, inout and value semantics) with a tested example of each, the compiler message where there is one, and the version to write instead.
module: m46
order: 5
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m46-l04]
objectives:
  - Index a String by position with String.Index or by converting it to an Array first, and say what each costs.
  - Work with Character, asciiValue and Unicode scalars without crashing on non-ASCII input.
  - Avoid and detect integer overflow, and normalize % for negative numbers.
  - Use Dictionary's default subscript and never rely on dictionary iteration order.
  - Choose between sort and sorted, pass arrays with inout, and predict what value semantics copies.
terms:
  - term: String.Index
    definition: The opaque position type for String. Moving it n characters costs O(n), because characters have variable width in memory.
  - term: Overflow trap
    definition: Swift stops the program when integer arithmetic produces a result that doesn't fit the type, instead of wrapping around silently.
  - term: Overflow operators
    definition: "&+, &- and &*, which wrap around on overflow instead of trapping. Rarely what you want in an interview, but worth knowing."
  - term: Default subscript
    definition: "dictionary[key, default: value] reads value when the key is missing, and supports in-place updates like counts[key, default: 0] += 1."
  - term: Value semantics
    definition: Assigning or passing a struct, array, dictionary or string gives an independent copy. Class instances are shared references instead.
mastery:
  - Rewrite code that indexes a String with an Int into a version that compiles and is O(1) per access.
  - Convert a letter to a 0–25 position without a UInt8 underflow trap.
  - Explain why Int.max + 1 doesn't compile but the same addition at runtime stops the program, and use addingReportingOverflow.
  - Count with a default subscript and print counts in a deterministic order.
  - Predict the result of mutating a struct read out of a dictionary, and of Array(repeating:count:) with a class instance.
resources: [swift-string, swift-int-adding-reporting-overflow, swift-dictionary-default-subscript, swift-book-strings, swift-book-basic-operators, swift-dictionary, swift-array-sort, swift-book-functions, swift-book-structures-classes]
cards:
  - id: m46-l05-c1
    front: "Why doesn't word[0] compile for a String, and what do you write instead?"
    back: "\"'subscript(_:)' is unavailable: cannot subscript String with an Int\". Characters have variable width, so positions are String.Index values. Use word.index(word.startIndex, offsetBy: k) (O(k)), or convert once with Array(word) for O(1) access."
  - id: m46-l05-c2
    front: "What's the safe way to get a letter's position 0–25?"
    back: "Int(letter.asciiValue!) - Int(Character(\"a\").asciiValue!), converting to Int before subtracting. Subtracting the UInt8 values directly traps when the result would be negative, and asciiValue is nil for non-ASCII characters."
  - id: m46-l05-c3
    front: What does Swift do on integer overflow?
    back: "It stops the program (a trap) instead of wrapping. A constant expression like Int.max + 1 is a compile error. addingReportingOverflow(_:) returns (partialValue, overflow) so you can check; &+ wraps silently."
  - id: m46-l05-c4
    front: "What's -7 % 3 in Swift, and how do you get a non-negative remainder?"
    back: "-1. % keeps the sign of the left operand. Use ((x % m) + m) % m for a result in 0..<m."
  - id: m46-l05-c5
    front: "var c = dict[\"a\"]!; c.count += 1 — does dict change?"
    back: "No. c is a copy of the struct. Write it back with dict[\"a\"] = c, or mutate in place with dict[\"a\"]?.count += 1."
---

## The idea in one sentence

Swift is strict where many languages are loose (strings, integers, mutation), so a few habits keep you from losing interview time to the compiler or to a crash.

Each section shows the surprise, proves it with a block that the course's tests compiled and ran, and gives the version to write instead.

## 1. Strings don't take integer subscripts

```swift no-compile cannot subscript String with an Int
let word = "swift"
print(word[0])
```

Swift 6.3 says: `error: 'subscript(_:)' is unavailable: cannot subscript String with an Int, use a String.Index instead.` A `Character` can take several bytes in memory (lesson 2), so the k-th character's position can't be computed in O(1). Swift makes that cost visible by using `String.Index` for positions:

```swift
let word = "swift"
let third = word[word.index(word.startIndex, offsetBy: 2)]
print(third)

let fIndex = word.firstIndex(of: "f")!
print(word[..<fIndex], word.distance(from: word.startIndex, to: fIndex))

let letters = Array(word)
print(letters[2], letters[letters.count - 1])
```

```output
i
swi 3
i t
```

`index(_:offsetBy:)` walks from the start, so it's O(k). Inside a loop that does it for every k, the loop becomes O(n²). In interviews, **convert once with `Array(word)`**: O(n) time and space up front, then O(1) per access, and two-pointer or sliding-window code reads exactly as it does with an array of numbers. Say the trade-off when you do it: "I'm converting to an array of Characters for O(1) indexing; that's O(n) extra space."

`word.count` is O(n) too, for the same reason. Read it once into a constant if you need it repeatedly.

## 2. Character, asciiValue and Unicode scalars

A `Character` is what a user sees as one character, possibly several Unicode scalars. For letter arithmetic, `asciiValue` gives a `UInt8`, or `nil` for anything outside ASCII:

```swift
let accented = "e\u{301}"
print(accented.count, accented.unicodeScalars.count)
for scalar in accented.unicodeScalars {
    print(scalar.value)
}

let aValue = Int(Character("a").asciiValue!)
print(Int(Character("z").asciiValue!) - aValue)
print(Int(Character("A").asciiValue!) - aValue)
print(Character("é").asciiValue == nil)
print(Character("7").wholeNumberValue ?? -1, Character("x").wholeNumberValue ?? -1)
```

```output
1 2
101
769
25
-32
true
7 -1
```

Two traps hide here:

- **`UInt8` subtraction.** `Character("A").asciiValue! - Character("a").asciiValue!` is 65 − 97 in `UInt8`, which can't be negative. It doesn't wrap; the program stops. Convert to `Int` **before** subtracting, as above, and the result is simply −32.
- **`asciiValue!` on non-ASCII input.** `"é"` has no ASCII value. Force-unwrap only under an agreed precondition (lesson 2), or use `guard let`.

`wholeNumberValue` turns a digit character into an `Int?`, which saves a `String` round trip when parsing digits one at a time.

## 3. Integer overflow stops the program

When the compiler can see the overflow, it refuses to build:

```swift no-compile results in an overflow
let tooBig = Int.max + 1
print(tooBig)
```

Swift 6.3 reports: `error: arithmetic operation '9223372036854775807 + 1' (on type 'Int') results in an overflow`. When the values only exist at runtime, the same addition compiles, and the program stops when it happens. It doesn't wrap around to a negative number the way C or Java do. The exact crash report depends on the platform, so the course doesn't quote one.

To check instead of crashing, use the reporting methods:

```swift
let result = Int.max.addingReportingOverflow(1)
print(result.overflow, result.partialValue == Int.min)

let low = 9_000_000_000_000_000_000
let high = 9_100_000_000_000_000_000
print(low.addingReportingOverflow(high).overflow)
print(low + (high - low) / 2)

let small: Int8 = 127
print(small &+ 1)
```

```output
true true
true
9050000000000000000
-128
```

- `addingReportingOverflow(_:)` returns `(partialValue, overflow)`. There are matching `subtracting…` and `multipliedReportingOverflow(by:)` methods.
- `low + (high - low) / 2` is the midpoint that can't overflow, from binary search (Module 15). `(low + high) / 2` would trap with these values.
- `&+` wraps on overflow. It's correct for hashing and checksums, and almost never what an interview answer needs.

In interviews, the useful habit is to **say** where overflow could happen: sums of many values, products, `n * (n + 1) / 2`. Then say why it can't with the given constraints, or switch to a safer formula, as with XOR in lesson 3.

## 4. % keeps the sign of the left operand

```swift
print(-7 % 3, -7 / 3, 7 % -3)
let position = -7
let size = 3
print(((position % size) + size) % size)
```

```output
-1 -2 1
2
```

Swift's `/` truncates toward zero, and `%` is defined so that `(a / b) * b + a % b == a`. So `-7 % 3` is −1, not 2. Using that as an array index crashes. Whenever a value can be negative (circular buffers, rotating by a negative offset, the "durations can be negative" follow-up from lesson 1), normalize with `((x % m) + m) % m`.

## 5. Dictionary subscripts and order

Reading a dictionary returns an optional, and the default subscript gives you counting in one line:

```swift
let words = ["pear", "fig", "pear", "kiwi", "fig", "pear"]
var counts: [String: Int] = [:]
for word in words {
    counts[word, default: 0] += 1
}
print(counts["pear"] ?? 0, counts["plum"] ?? 0)
print(counts["plum", default: 0])
for word in counts.keys.sorted() {
    print(word, counts[word]!)
}
```

```output
3 0
0
fig 2
kiwi 1
pear 3
```

- `counts[word, default: 0] += 1` reads 0 for a missing key and stores the result. No `if let`, no force unwrap.
- `counts["plum", default: 0]` **reads** without inserting anything.
- The last loop sorts the keys. A `Dictionary` (and a `Set`) has no defined order, and Swift seeds its hashing randomly per process, so iterating or printing one can give a different order on each run. An interview answer that returns `Array(counts.keys)` without sorting can look right once and wrong the next time. If the problem wants an order, produce it explicitly.
- Assigning `nil` (`counts["fig"] = nil`) removes the key.

## 6. sort versus sorted

`sorted()` returns a new array; `sort()` sorts in place and returns nothing. Mixing them up gives two different messages:

```swift no-compile cannot use mutating member on immutable value
let scores = [3, 1, 2]
scores.sort()
```

Swift 6.3: `error: cannot use mutating member on immutable value: 'scores' is a 'let' constant`.

```swift warning constant 'result' inferred to have type '()'
var scores = [3, 1, 2]
let result = scores.sort()
print(result, scores)
```

```output
() [1, 2, 3]
```

Here it compiles with `warning: constant 'result' inferred to have type '()', which may be unexpected`. `result` is the empty tuple, `()`, because `sort()` returns nothing. The correct pairs are:

```swift
let original = [3, 1, 2]
let ascending = original.sorted()
var inPlace = original
inPlace.sort(by: >)
print(original, ascending, inPlace)
```

```output
[3, 1, 2] [1, 2, 3] [3, 2, 1]
```

Both are O(n log n), and Apple's documentation states that they're stable (Module 18). `sorted()` costs O(n) extra space for the new array.

## 7. Parameters are constants; inout needs &

```swift no-compile 'values' is a 'let' constant
func addBonus(_ values: [Int]) {
    values.append(10)
}
```

Swift 6.3: `error: cannot use mutating member on immutable value: 'values' is a 'let' constant`. Either copy into a `var` inside the function (the caller's array is untouched), or declare the parameter `inout` so the function changes the caller's array. With `inout`, the call site has to say so:

```swift no-compile requires explicit '&'
func addBonus(_ values: inout [Int]) {
    values.append(10)
}

var points = [1, 2]
addBonus(points)
```

Swift 6.3: `error: passing value of type '[Int]' to an inout parameter requires explicit '&'`. The working version:

```swift
func addBonus(_ values: inout [Int]) {
    values.append(10)
}

var points = [1, 2]
addBonus(&points)
print(points)
```

```output
[1, 2, 10]
```

Use `inout` when the problem says "in place" and the interviewer wants O(1) extra space. Recursive helpers that fill a shared result (backtracking, Module 18) are the other common use.

## 8. Value semantics surprises

People coming from languages where arrays and objects are references get caught by the opposite behavior in Swift, and people who've only used Swift get caught by classes:

```swift
struct Counter {
    var count = 0
}

var counters = ["likes": Counter()]
var copy = counters["likes"]!
copy.count += 1
print(counters["likes"]!.count)

counters["likes"]?.count += 1
print(counters["likes"]!.count)

var grid = Array(repeating: Array(repeating: 0, count: 3), count: 2)
grid[0][0] = 7
print(grid)

final class Node {
    var value = 0
}

let nodes = Array(repeating: Node(), count: 3)
nodes[0].value = 7
print(nodes.map { $0.value })
print(nodes[0] === nodes[2])
```

```output
0
1
[[7, 0, 0], [0, 0, 0]]
[7, 7, 7]
true
```

Line by line:

1. `copy` is an independent copy of the struct. Changing it doesn't touch the dictionary.
2. `counters["likes"]?.count += 1` mutates the value **inside** the dictionary through optional chaining. Assigning `counters["likes"] = copy` would also work.
3. A grid built with nested `Array(repeating:count:)` has independent rows, because arrays are values. (In Python, the equivalent `[[0] * 3] * 2` shares the row. In Swift, it doesn't.)
4. With a **class**, `Array(repeating: Node(), count: 3)` calls `Node()` once and stores the same reference three times. Changing one changes "all three", because there's only one. `===` confirms it's the same instance. Build distinct instances with `(0..<3).map { _ in Node() }`.

This shows up in graph and tree problems, where nodes are often classes: a visited array of structs and a list of class nodes behave differently when you modify them.

## 9. Costs that hide in convenient calls

| Call | Cost | What to use instead in a hot loop |
| --- | --- | --- |
| `array.removeFirst()` | O(n): shifts every element | An index that moves forward, or `removeLast()`/`popLast()` (O(1)) on a reversed array (Module 17) |
| `array.contains(x)`, `firstIndex(of:)` | O(n) | A `Set` or a dictionary from value to index |
| `string.count` | O(n) | Read it once; or work on `Array(string)` |
| `string.index(_:offsetBy: k)` | O(k) | `Array(string)` |
| `array.insert(x, at: 0)` | O(n) | Append and reverse at the end |
| `sorted()` inside a loop | O(n log n) per pass | Sort once, before the loop |

None of these are wrong. They become wrong inside a loop that runs n times, which turns an O(n) solution into O(n²) without any visible nested loop. When you state complexity (lesson 3), these are the calls to look for.

## Common mistakes

> [!error] error: 'subscript(_:)' is unavailable: cannot subscript String with an Int
> Convert once with `Array(text)` and index the array, or use `String.Index`. Don't call `index(_:offsetBy:)` inside a loop over every position.

> [!error] Subtracting asciiValue as UInt8
> `c.asciiValue! - Character("a").asciiValue!` stops the program for any c that comes before "a" (uppercase letters, digits, punctuation). Convert both to `Int` first.

> [!error] Using % on a value that might be negative as an index
> `-1 % 26` is −1, and `letters[-1]` crashes. Normalize with `((x % m) + m) % m`.

> [!error] Returning a dictionary's keys without an order
> The order can change between runs. If the problem asks for an order, sort; if it doesn't, say so and don't let tests depend on it.

> [!error] Array(repeating:count:) with a class instance
> One instance, repeated. Use `map` over a range to create one per slot.

## Exercises

````exercise
id: m46-l05-e1
type: prediction
prompt: Predict the exact output.
code: |
  struct Score {
      var points = 0
  }

  final class Player {
      var points = 0
  }

  var scores = ["ana": Score()]
  var ana = scores["ana"]!
  ana.points = 10
  print(scores["ana"]!.points)

  var players = ["bo": Player()]
  let bo = players["bo"]!
  bo.points = 10
  print(players["bo"]!.points)

  let team = Array(repeating: Player(), count: 2)
  team[1].points = 5
  print(team[0].points)

  players["bo"] = nil
  print(players.count, bo.points)
output: |
  0
  10
  5
  0 10
hints:
  - Score is a struct; Player is a class.
  - Array(repeating:count:) evaluates its first argument once.
  - Removing a key from the dictionary doesn't destroy an object someone else still references.
solution: |
  ```output
  0
  10
  5
  0 10
  ```

  - `ana` is a copy of the struct, so the dictionary still holds 0.
  - `bo` is a reference to the same `Player` the dictionary holds, so setting its points changes what the dictionary sees: 10.
  - `team` holds one `Player` twice. Changing `team[1]` changes `team[0]`, because they're the same object: 5.
  - Assigning `nil` removes the key, so the dictionary is empty. The `Player` is still alive, because `bo` references it, and its points are still 10.
````

````exercise
id: m46-l05-e2
type: prediction
prompt: Predict the exact output.
code: |
  let offsets = [-8, -3, 0, 5, 9]
  for offset in offsets {
      print(offset % 4, ((offset % 4) + 4) % 4)
  }
  let sum = Int.max.addingReportingOverflow(-1)
  print(sum.overflow)
  let product = (Int.max / 2).multipliedReportingOverflow(by: 3)
  print(product.overflow)
output: |
  0 0
  -3 1
  0 0
  1 1
  1 1
  false
  true
hints:
  - "% keeps the sign of the left operand: -3 % 4 is -3."
  - Int.max − 1 fits. Int.max / 2 times 3 is about 1.5 × Int.max.
solution: |
  ```output
  0 0
  -3 1
  0 0
  1 1
  1 1
  false
  true
  ```

  `-8 % 4` is 0 (−8 is a multiple of 4; Swift prints 0, not −0). `-3 % 4` is −3, and normalizing gives 1: on a ring of positions 0 to 3, −3 and 1 are the same position (−3 + 4 = 1). Positive values are unchanged by the normalization. `Int.max + (-1)` doesn't overflow; `(Int.max / 2) * 3` does, and the reporting method returns `true` instead of stopping the program.
````

````exercise
id: m46-l05-e3
type: find-errors
prompt: This function should return true if a string reads the same forward and backward, comparing characters exactly. Which statements are true?
code: |
  func isMirrored(_ text: String) -> Bool {
      var left = 0
      var right = text.count - 1
      while left < right {
          let leftIndex = text.index(text.startIndex, offsetBy: left)
          let rightIndex = text.index(text.startIndex, offsetBy: right)
          if text[leftIndex] != text[rightIndex] {
              return false
          }
          left += 1
          right -= 1
      }
      return true
  }
choices:
  - text: "It compiles and gives correct answers, but each index(_:offsetBy:) call is O(n), so the function is O(n²)."
    correct: true
    why: Every pass walks from startIndex. About n/2 passes of up to n steps each.
  - text: "It doesn't compile, because String can't be indexed."
    correct: false
    why: It indexes with String.Index values, which is allowed. Only Int subscripts are unavailable.
  - text: "With an empty string, text.count - 1 is -1 and the program crashes."
    correct: false
    why: right is −1, left is 0, and the loop condition 0 < −1 is false, so it returns true without indexing.
  - text: "Converting once with Array(text) makes it O(n) time, at the cost of O(n) extra space."
    correct: true
    why: One O(n) conversion, then O(1) per access.
rubric:
  - I identified the hidden O(n²) from index(_:offsetBy:) inside the loop.
  - I checked the empty string by tracing it instead of guessing.
  - I rewrote it with Array(text) and stated the space trade-off.
solution: |
  The answers are correct; the cost isn't. A version with O(1) access:

  ```swift
  func isMirrored(_ text: String) -> Bool {
      let characters = Array(text)
      var left = 0
      var right = characters.count - 1
      while left < right {
          if characters[left] != characters[right] {
              return false
          }
          left += 1
          right -= 1
      }
      return true
  }

  print(isMirrored("level"), isMirrored("swift"), isMirrored(""), isMirrored("e\u{301}xe\u{301}"))
  ```

  ```output
  true false true true
  ```

  O(n) time and O(n) extra space for the array. Because the array holds `Character`s, an accented letter made of two scalars stays one element, and the last call is still a mirror. Walking two `String.Index` values inward with `text.index(after:)` and `text.index(before:)` would avoid the extra space and stay O(n); it's more code, and worth mentioning as the follow-up.
````

````exercise
id: m46-l05-e4
type: solve
prompt: |
  Write `func shifted(_ text: String, by offset: Int) -> String` that shifts every lowercase ASCII letter by `offset` positions in the alphabet, wrapping around (`"z"` shifted by 1 is `"a"`). The offset can be negative or larger than 26. Every other character, including accented letters, stays as it is.

  Use `asciiValue` without any `UInt8` subtraction that could trap, and normalize the remainder. Expected output for the starter's calls:

  ```output
  khoor, zruog
  zab
  abc
  dbgé

  ```
starter: |
  func shifted(_ text: String, by offset: Int) -> String {
      return text
  }

  print(shifted("hello, world", by: 3))
  print(shifted("abc", by: -1))
  print(shifted("xyz", by: 29))
  print(shifted("café", by: 1))
  print(shifted("", by: 5))
hints:
  - "guard let ascii = character.asciiValue, character.isLowercase else { keep it as is }"
  - Convert to Int before subtracting the value of "a".
  - "((position + offset) % 26 + 26) % 26 is always in 0..<26."
  - "Character(Unicode.Scalar(UInt8(value))) builds a Character from an ASCII value."
rubric:
  - Skips non-lowercase and non-ASCII characters without crashing.
  - Converts to Int before subtracting.
  - Normalizes with ((x % 26) + 26) % 26 so negative and large offsets work.
  - The output matches, including the accented letter and the empty string.
solution: |
  ```swift
  func shifted(_ text: String, by offset: Int) -> String {
      let aValue = Int(Character("a").asciiValue!)
      var result = ""
      for character in text {
          guard let ascii = character.asciiValue, character.isLowercase else {
              result.append(character)
              continue
          }
          let position = Int(ascii) - aValue
          let newPosition = ((position + offset) % 26 + 26) % 26
          result.append(Character(Unicode.Scalar(UInt8(aValue + newPosition))))
      }
      return result
  }

  print(shifted("hello, world", by: 3))
  print(shifted("abc", by: -1))
  print(shifted("xyz", by: 29))
  print(shifted("café", by: 1))
  print(shifted("", by: 5))
  ```

  ```output
  khoor, zruog
  zab
  abc
  dbgé

  ```

  - `asciiValue` is `nil` for "é", so the `guard` keeps it unchanged; "c", "a" and "f" shift to "d", "b" and "g".
  - `Int(ascii) - aValue` is computed in `Int`, so nothing can underflow.
  - `% 26` brings an offset of 29 down to 3, and adding 26 before the second `%` fixes negative results: "a" shifted by −1 gives `((0 - 1) % 26 + 26) % 26`, which is 25, "z".
  - `UInt8(aValue + newPosition)` is between 97 and 122, so the conversion can't fail, and `Unicode.Scalar(_:)` from a `UInt8` always succeeds.

  O(n) time for n characters, and O(n) for the result.
````

````exercise
id: m46-l05-e5
type: fill-in
prompt: Complete the word counter so it prints each word with its count, in alphabetical order, the same way on every run.
code: |
  let words = ["b", "a", "c", "a", "b", "a"]
  var counts: [String: Int] = [:]
  for word in words {
      counts[word, [[1]]: 0] += 1
  }
  for word in counts.keys.[[2]]() {
      print(word, counts[word]!)
  }
blanks:
  - id: "1"
    answers: ["default"]
  - id: "2"
    answers: ["sorted"]
solution: |
  ```swift
  let words = ["b", "a", "c", "a", "b", "a"]
  var counts: [String: Int] = [:]
  for word in words {
      counts[word, default: 0] += 1
  }
  for word in counts.keys.sorted() {
      print(word, counts[word]!)
  }
  ```

  ```output
  a 3
  b 2
  c 1
  ```

  `default: 0` makes the first increment of each word start from 0. `keys.sorted()` gives a fixed order; iterating `counts` directly could list the words in a different order on each run. The force unwrap in `counts[word]!` is safe because `word` came from the dictionary's own keys.
````

````exercise
id: m46-l05-e6
type: comprehension
multiple: true
prompt: Inside a loop that runs once per element of an n-element array, which calls keep the whole loop O(n)? Select all that apply.
choices:
  - text: "letters[i], where letters = Array(text) was built before the loop"
    correct: true
    why: Array subscripts are O(1).
  - text: "counts[key, default: 0] += 1 on a dictionary"
    correct: true
    why: O(1) on average.
  - text: "queue.removeFirst() on an array"
    correct: false
    why: O(n) per call, because every remaining element shifts. The loop becomes O(n²).
  - text: "text.index(text.startIndex, offsetBy: i)"
    correct: false
    why: O(i) per call, O(n²) in total.
  - text: "stack.popLast() on an array"
    correct: true
    why: Removing from the end is O(1).
  - text: "seen.contains(x) where seen is an Array"
    correct: false
    why: A linear scan. Use a Set for O(1) on average.
solution: |
  Array subscripts, dictionary updates and `popLast()` are O(1) (on average, for the dictionary), so the loop stays O(n). `removeFirst()`, `index(_:offsetBy:)` and `Array.contains` are each O(n) or O(i), so calling them once per iteration makes the loop O(n²). This is the most common way an "O(n)" answer is actually quadratic.
````

## Summary

- `text[0]` doesn't compile. Convert once with `Array(text)` for O(1) indexing (O(n) space), or use `String.Index`; `index(_:offsetBy:)` and `count` are O(n).
- A `Character` can be several Unicode scalars. Convert `asciiValue` to `Int` before subtracting, and don't force-unwrap it on input that might not be ASCII.
- Overflow stops the program at runtime and is a compile error in constant expressions. Use `addingReportingOverflow` to check, `low + (high - low) / 2` for midpoints, and say where overflow could happen.
- `%` keeps the left operand's sign: `-7 % 3` is −1. Normalize with `((x % m) + m) % m`.
- `dict[key, default: 0] += 1` counts in one line. Dictionaries and sets have no stable order; sort keys before printing or returning them.
- `sorted()` returns a copy; `sort()` mutates a `var` and returns `()`. Parameters are constants; `inout` needs `&` at the call site.
- Structs copy, classes share: a struct read out of a dictionary is a copy, and `Array(repeating: SomeClass(), count: n)` holds one instance n times.
- `removeFirst()`, `contains` on arrays, and `index(_:offsetBy:)` inside a loop turn O(n) into O(n²).
