---
id: m07-l01
title: "Arrays: storing values in order"
description: You create arrays, read elements by index, add and remove elements, and learn why reading past the end crashes your program and how to check before you read.
module: m07
order: 1
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m06-l06]
objectives:
  - Create arrays with a literal, as an empty array with a type annotation, and with Array(repeating:count:).
  - Read count and isEmpty, and read and change elements by index.
  - Explain zero-based indexes and name the valid indexes of any array.
  - Add and remove elements with append, insert(_:at:) and remove(at:).
  - Check an index before using it, and explain why an invalid index crashes.
terms:
  - term: Array
    definition: An ordered collection of values of the same type. The type of an array of integers is written [Int].
  - term: Element
    definition: One of the values stored in a collection.
  - term: Index
    definition: The position of an element in an array. Array indexes start at 0, so the last valid index is count - 1.
  - term: Subscript
    definition: The square-bracket syntax for reading or writing an element by position or key, like scores[2].
  - term: Mutating method
    definition: A method that changes the value it's called on, like append. It only works on a var.
mastery:
  - Write the type of an array literal and declare an empty array of any element type.
  - Say which indexes are valid for an array with a given count, including an empty array.
  - Predict the contents of an array after a sequence of append, insert and remove calls.
  - Write a function that returns an element at an index, or a default value when the index is invalid.
  - Fix the "empty collection literal requires an explicit type" and "cannot use mutating member on immutable value" errors.
resources: [swift-array, swift-book-collection-types, swift-book-basics]
cards:
  - id: m07-l01-c1
    front: What are the valid indexes of an array with count 5?
    back: 0 through 4. Indexes start at 0, so the last one is count - 1. An empty array has no valid indexes at all.
  - id: m07-l01-c2
    front: What happens when you read scores[10] and scores has 3 elements?
    back: "The program crashes at runtime with \"Fatal error: Index out of range\". The compiler can't catch it. Check the index first: index >= 0 && index < scores.count."
  - id: m07-l01-c3
    front: How do you declare an empty array of strings?
    back: "var names: [String] = []. Swift can't infer the element type from [] alone, so you have to write it."
  - id: m07-l01-c4
    front: What do append, insert(_:at:) and remove(at:) do?
    back: "append adds an element at the end. insert(x, at: i) puts x at index i and shifts the rest right. remove(at: i) takes out the element at i, shifts the rest left and returns the removed element. All three need a var."
---

## The idea in one sentence

An array is a numbered list of values of one type: you get each value back by its position, starting from 0.

## Why you need arrays

Say you want to store five temperatures. With what you know so far, you'd write `let temperature1 = 18`, `let temperature2 = 31` and so on. That works for five, but not for a week of hourly readings, and it falls apart when you don't know in advance how many values there will be. You can't write a loop over `temperature1` through `temperature5`.

You've already seen the fix in passing: in Module 5 you looped over `["Lima", "Bogotá", "Quito"]`. That's an array. This lesson is about the array itself.

## Creating an array

**Plain definition:** an array is a list of values kept in the order you put them in.

**Precise definition:** `Array<Element>`, almost always written `[Element]`, is an ordered, random-access collection whose elements all have the same type. Duplicates are allowed. Each element is identified by an integer **index**.

```swift
let temperatures = [18, 31, 24, 33, 29]
let cities: [String] = ["Lima", "Bogotá", "Quito"]
print(temperatures)
print(cities)
print(temperatures.count)
print(cities.isEmpty)
```

```output
[18, 31, 24, 33, 29]
["Lima", "Bogotá", "Quito"]
5
false
```

Line by line:

1. An **array literal** is a list of values in square brackets, separated by commas. Swift infers the type `[Int]` from the elements.
2. The same thing with an explicit annotation: `[String]` reads "array of String".
3. `print` shows the whole array in brackets.
4. Strings are printed with their quotes, so you can tell `"5"` from `5`.
5. `count` is the number of elements.
6. `isEmpty` is `true` when `count` is 0. Prefer it over `count == 0`: it says what you mean.

### Empty arrays need a type

To start with no elements, you have to tell Swift the element type, because `[]` alone gives it nothing to infer from:

```swift
var names: [String] = []
var scores = [Int]()
print(names.count, scores.isEmpty)
names.append("Ana")
scores.append(90)
print(names, scores)
```

```output
0 true
["Ana"] [90]
```

Both forms create an empty array. `[Int]()` calls the array type like a function, the same way `Int("42")` calls `Int`. The annotation form, `var names: [String] = []`, is the one you'll see most.

### An array of repeated values

`Array(repeating:count:)` builds an array with the same value in every position. It's handy for counters and boards:

```swift
let zeros = Array(repeating: 0, count: 4)
let row = Array(repeating: "-", count: 3)
print(zeros)
print(row)
```

```output
[0, 0, 0, 0]
["-", "-", "-"]
```

## Indexes start at 0

Every element has a position, its **index**. The first element is at index **0**, not 1. So an array with `count` elements has the indexes `0` through `count - 1`.

```swift
let cities = ["Lima", "Bogotá", "Quito"]
print(cities[0])
print(cities[2])
print(cities[cities.count - 1])
print(cities.indices)
```

```output
Lima
Quito
Quito
0..<3
```

| Index | 0 | 1 | 2 |
| --- | --- | --- | --- |
| Element | "Lima" | "Bogotá" | "Quito" |

1. `cities[0]` is a **subscript**: the array's name followed by an index in square brackets. It reads the first element.
2. `cities[2]` is the third and last.
3. `cities.count - 1` is always the last valid index. Here it's `3 - 1 = 2`.
4. `indices` is the range of valid indexes, `0..<3`. It's the half-open range from Module 5: 0, 1 and 2, but not 3.

Why 0? An index is an **offset from the start**: the first element is 0 steps from the beginning, the second is 1 step away. Most languages count this way. You'll get used to it, but it's the main source of off-by-one errors with arrays, so whenever you write `count`, ask yourself whether you meant `count - 1`.

## Reading past the end crashes

If you ask for an index that doesn't exist, Swift doesn't hand you garbage or a default. It **stops the program**:

```swift runtime-error Index out of range
let cities = ["Lima", "Bogotá", "Quito"]
print("Before")
print(cities[3])
print("After")
```

```output
Before
```

The program printed `Before`, then crashed with `Fatal error: Index out of range` on the next line. `After` never ran. The compiler can't catch this one: the index might come from a calculation or from the user, and the array's size might change while the program runs. It's a **runtime error**, like dividing by zero.

Crashing sounds harsh, but it's the safe choice. A program that silently read memory past the end of the array would keep running with wrong data, which is how many security holes in older languages happen.

### Checking before you read

The fix is to check the index before you use it. An index is valid when it's at least 0 and less than `count`:

```swift
func city(at index: Int, in cities: [String]) -> String {
    guard index >= 0 && index < cities.count else {
        return "No city at \(index)"
    }
    return cities[index]
}

let cities = ["Lima", "Bogotá", "Quito"]
print(city(at: 1, in: cities))
print(city(at: 3, in: cities))
print(city(at: -1, in: cities))
```

```output
Bogotá
No city at 3
No city at -1
```

The parameter type `[String]` works like any other type: the function receives an array of strings. The `guard` from Module 5 rules out both kinds of bad index, too big and negative. You can say the same thing with `cities.indices.contains(index)`, which asks whether the index is inside the range of valid indexes.

### first and last

Arrays have `first` and `last` for the two ends. Because the array might be empty, they don't return an element. They return an **optional**: either an element or nothing. Module 8 covers optionals properly; for now, use `??` to supply a default, the same way you did with `Int("…")`:

```swift
let queue = ["Ana", "Luis", "Marta"]
let empty: [String] = []
print(queue.first ?? "nobody")
print(queue.last ?? "nobody")
print(empty.first ?? "nobody")
```

```output
Ana
Marta
nobody
```

`queue.first` can never crash, which is the difference from `queue[0]`: on an empty array, `queue[0]` crashes and `queue.first` gives you nothing.

## Changing an array

An array declared with `var` can change: you can replace elements, add them and remove them.

```swift
var playlist = ["Intro", "Song A", "Song B"]
playlist[1] = "Song A (live)"
playlist.append("Outro")
playlist.insert("Warm-up", at: 0)
print(playlist)
let removed = playlist.remove(at: 2)
print(removed)
print(playlist)
print(playlist.count)
```

```output
["Warm-up", "Intro", "Song A (live)", "Song B", "Outro"]
Song A (live)
["Warm-up", "Intro", "Song B", "Outro"]
4
```

Line by line:

1. A `var` array with three elements.
2. Assigning through a subscript replaces the element at index 1. The index has to exist already; you can't add an element this way.
3. `append` adds an element **at the end**.
4. `insert(_:at:)` puts an element at an index and pushes everything from there one place to the right. `"Intro"` moves from 0 to 1.
5. The array now has five elements.
6. `remove(at:)` takes out the element at index 2, shifts everything after it one place left, and **returns** the removed element. If you don't need it, you can ignore the result.
7. Prints what was removed.
8. The array after the removal.
9. Four elements left.

`insert` and `remove` need a valid position too. `insert` accepts any index from 0 to `count` (inserting at `count` is the same as `append`); `remove(at:)` needs an existing index. Outside those, both crash like a bad subscript.

A few more you'll use:

```swift
var numbers = [4, 8]
numbers += [15, 16]
numbers.removeLast()
print(numbers)
numbers.removeAll()
print(numbers, numbers.isEmpty)
```

```output
[4, 8, 15]
[] true
```

`+=` appends all the elements of another array. `removeLast()` removes the last element (and crashes on an empty array). `removeAll()` empties the array.

## let arrays can't change

A `let` array is completely fixed: you can't add, remove or replace anything in it. This is the same `let` from Module 4, applied to the whole collection.

```swift no-compile cannot use mutating member on immutable value: 'names' is a 'let' constant
let names = ["Ana", "Luis"]
names.append("Marta")
```

Swift 6.3 says `error: cannot use mutating member on immutable value: 'names' is a 'let' constant`. A **mutating member** is a method that changes the value it's called on, like `append`, `insert` or `remove(at:)`. Writing through a subscript fails the same way, with a slightly different message:

```swift no-compile cannot assign through subscript: 'names' is a 'let' constant
let names = ["Ana", "Luis"]
names[0] = "Marta"
```

The rule from Module 4 still holds: **`let` by default**, `var` only when the array really changes after you create it.

## One type per array

All elements of an array share one type. Swift won't guess a common type for you:

```swift no-compile heterogeneous collection literal could only be inferred to '[Any]'
let mixed = [1, "two", 3]
```

The full message in Swift 6.3 is `heterogeneous collection literal could only be inferred to '[Any]'; add explicit type annotation if this is intentional`. "Heterogeneous" means "of different kinds". `[Any]` exists, but you almost never want it: you'd lose the type checking that tells you what each element is. If you have a number and a name that belong together, that's a tuple (Module 6) or a struct (Module 9), not a mixed array.

The same rule applies when you add elements: appending a `String` to an `[Int]` fails with `cannot convert value of type 'String' to expected argument type 'Int'`.

## A practical example: a waiting list

A restaurant keeps a waiting list. Guests are added at the end, a VIP goes to the front, and the first guest is seated when a table opens.

```swift
var waitingList: [String] = []
waitingList.append("Ana")
waitingList.append("Luis")
waitingList.append("Marta")
waitingList.insert("Sofía", at: 0)
print("Waiting: \(waitingList.count)")

let seated = waitingList.remove(at: 0)
print("Seating \(seated)")
print("Next up: \(waitingList.first ?? "nobody")")
print("Last in line: \(waitingList.last ?? "nobody")")

let position = 5
if position >= 0 && position < waitingList.count {
    print("Guest at \(position): \(waitingList[position])")
} else {
    print("No guest at position \(position)")
}
```

```output
Waiting: 4
Seating Sofía
Next up: Ana
Last in line: Marta
No guest at position 5
```

Every read is either through `first`/`last` with a default or behind an index check, so this program can't crash no matter how short the list gets. The `remove(at: 0)` assumes the list isn't empty; in a real app you'd check `waitingList.isEmpty` first.

## Common mistakes

> [!error] error: empty collection literal requires an explicit type
> You wrote `let names = []`. Swift can't tell what kind of elements the array will hold. Add the type: `var names: [String] = []`. Swift 6.3:

```swift no-compile empty collection literal requires an explicit type
var names = []
names.append("Ana")
```

> [!error] Fatal error: Index out of range
> You read or wrote an index that doesn't exist, usually `array[array.count]` instead of `array[array.count - 1]`, or `array[0]` on an empty array. Check the index first, or use `first` and `last` with `??`.

> [!error] error: cannot use mutating member on immutable value
> You called `append`, `insert` or `remove` on a `let` array. If the array really changes, declare it with `var`.

> [!error] Assigning to an index that doesn't exist yet
> `scores[3] = 90` on an array with three elements doesn't add a fourth: it crashes. To add, use `append` or `insert`. A subscript only replaces existing elements.

> [!error] Thinking remove(at:) leaves a gap
> After `remove(at: 1)`, the element that was at 2 is now at 1. Indexes you computed before the removal may now point at different elements, or past the end.

````exercise
id: m07-l01-e1
type: comprehension
prompt: "`let letters = [\"a\", \"b\", \"c\", \"d\"]`. Which expression reads the last element without crashing?"
choices:
  - text: "`letters[letters.count]`"
    correct: false
    why: "count is 4, and index 4 doesn't exist. The last valid index is 3. This crashes with Index out of range."
  - text: "`letters[letters.count - 1]`"
    correct: true
    why: "count - 1 is 3, the last valid index."
  - text: "`letters[4]`"
    correct: false
    why: "Same problem: four elements means indexes 0 to 3."
  - text: "`letters[-1]`"
    correct: false
    why: "Swift arrays don't count from the end with negative indexes. -1 is out of range and crashes."
solution: |
  **`letters[letters.count - 1]`.** Indexes start at 0, so an array of four elements has indexes 0, 1, 2 and 3. `letters.count` is 4, one past the end. Negative indexes don't mean "from the end" in Swift, unlike Python. On an empty array even `count - 1` would crash (it's -1), which is why `letters.last ?? "none"` is the safer choice when the array could be empty.
````

````exercise
id: m07-l01-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  var stack = [10, 20, 30]
  stack.append(40)
  stack.insert(5, at: 1)
  print(stack)
  let taken = stack.remove(at: 3)
  print(taken, stack.count)
  stack[0] = stack[0] + stack[stack.count - 1]
  print(stack)
output: |
  [10, 5, 20, 30, 40]
  30 4
  [50, 5, 20, 40]
hints:
  - "insert(5, at: 1) pushes 20 and everything after it one place right."
  - Recount the indexes after each change.
solution: |
  ```output
  [10, 5, 20, 30, 40]
  30 4
  [50, 5, 20, 40]
  ```

  | Step | stack |
  | --- | --- |
  | start | [10, 20, 30] |
  | `append(40)` | [10, 20, 30, 40] |
  | `insert(5, at: 1)` | [10, 5, 20, 30, 40] |
  | `remove(at: 3)` returns 30 | [10, 5, 20, 40] |
  | `stack[0] = 10 + 40` | [50, 5, 20, 40] |

  After the insert, index 3 holds 30, not 40. Once 30 is removed there are four elements, so `stack.count - 1` is 3 and `stack[3]` is 40.
````

````exercise
id: m07-l01-e3
type: fill-in
prompt: |
  Complete the program so it compiles and prints exactly:

  ```output
  ["milk", "eggs", "bread"]
  3
  ```
code: |
  var shopping: [[[1]]] = []
  shopping.[[2]]("milk")
  shopping.append("bread")
  shopping.[[3]]("eggs", at: 1)
  print(shopping)
  print(shopping.[[4]])
blanks:
  - id: "1"
    answers: ["String"]
  - id: "2"
    answers: ["append"]
  - id: "3"
    answers: ["insert"]
  - id: "4"
    answers: ["count"]
solution: |
  ```swift
  var shopping: [String] = []
  shopping.append("milk")
  shopping.append("bread")
  shopping.insert("eggs", at: 1)
  print(shopping)
  print(shopping.count)
  ```

  ```output
  ["milk", "eggs", "bread"]
  3
  ```

  The empty array needs its element type, `[String]`. Two appends give `["milk", "bread"]`, and inserting at index 1 puts `"eggs"` between them. `count` is a property, so it has no parentheses.
````

````exercise
id: m07-l01-e4
type: find-errors
prompt: This program is supposed to keep a list of scores, add one, and print the first and last. Pick out the real problems.
code: |
  let scores = []
  scores.append(88)
  scores.append(92)
  print(scores[1])
  print(scores[scores.count])
choices:
  - text: "Line 1: an empty literal needs an explicit type."
    correct: true
    why: "empty collection literal requires an explicit type. It should be [Int]."
  - text: "Lines 2 and 3: append can't be called on a let array."
    correct: true
    why: "The array changes, so it has to be a var."
  - text: "Line 4 prints the first score."
    correct: true
    why: "Index 1 is the second element. The first is at index 0."
  - text: "Line 5 reads one past the end and crashes at runtime."
    correct: true
    why: "With two elements, count is 2 and the last index is 1."
  - text: "append only works with strings."
    correct: false
    why: "append works with any element type, as long as it matches the array's."
rubric:
  - I declared the array as a var with type [Int].
  - I read the first element with index 0 or first.
  - I read the last element with count - 1 or last.
  - My version compiles and prints 88 and 92.
solution: |
  ```swift
  var scores: [Int] = []
  scores.append(88)
  scores.append(92)
  print(scores[0])
  print(scores[scores.count - 1])
  ```

  ```output
  88
  92
  ```

  Two of the problems are compile errors (the missing type and `let`) and two are logic errors the compiler can't see: index 1 is the second element, and `scores[scores.count]` is one past the end, a crash at runtime. You could also write `print(scores.first ?? 0)` and `print(scores.last ?? 0)`, which don't crash even on an empty array.
````

````exercise
id: m07-l01-e5
type: solve
prompt: |
  Write a function `element(at index: Int, in values: [Int], default fallback: Int) -> Int` that returns the element at `index`, or `fallback` when the index isn't valid. Then call it so the program prints:

  ```output
  7
  -1
  -1
  -1
  ```

  Use the array `[3, 7, 9]` with indexes 1, 3 and -2, and an empty array with index 0, all with a fallback of -1.
starter: |
  func element(at index: Int, in values: [Int], default fallback: Int) -> Int {
      // Your code
      return fallback
  }
hints:
  - "A valid index is at least 0 and less than values.count."
  - An empty array has count 0, so no index passes that check.
rubric:
  - The function never crashes, whatever the index or the array.
  - It checks both ends, negative indexes and indexes that are too big.
  - It returns the element itself when the index is valid.
  - The output matches exactly.
solution: |
  ```swift
  func element(at index: Int, in values: [Int], default fallback: Int) -> Int {
      guard index >= 0 && index < values.count else {
          return fallback
      }
      return values[index]
  }

  let numbers = [3, 7, 9]
  let empty: [Int] = []
  print(element(at: 1, in: numbers, default: -1))
  print(element(at: 3, in: numbers, default: -1))
  print(element(at: -2, in: numbers, default: -1))
  print(element(at: 0, in: empty, default: -1))
  ```

  ```output
  7
  -1
  -1
  -1
  ```

  The `guard` covers both ways an index can be wrong. With the empty array, `0 < 0` is false, so the function returns the fallback instead of crashing on `values[0]`. Note that -1 doubles as a sentinel here, the same weakness you saw in Module 6: if -1 were a real element, the caller couldn't tell the difference. Module 8 gives you a better return type.
````

````exercise
id: m07-l01-e6
type: explain
prompt: Explain why `scores[5]` on a three-element array isn't a compile error, and why Swift crashes the program instead of returning some default value like 0.
code: |
  let scores = [70, 85, 90]
  let index = 5
  print(scores[index])
rubric:
  - I explained that the index and the array's size are only known for sure while the program runs.
  - I explained that a silent default like 0 would look like real data.
  - I named a way to avoid the crash, such as checking the index against count.
solution: |
  The compiler checks types, not values. `index` is an `Int` and `scores` is an `[Int]`, so `scores[index]` is a correctly typed expression. In general the index could come from user input or a calculation, and the array could grow or shrink, so whether index 5 exists is only known at runtime.

  Returning 0 would be worse than crashing. A score of 0 looks like a real score: the program would carry on, average it in and print a wrong answer that nobody notices. A crash is loud and points to the exact line. To avoid it, check first (`index >= 0 && index < scores.count`), or use an API that can say "nothing here", like `first` and `last`, which return optionals.
````

## Summary

- An array, `[Element]`, stores values of one type in order. Duplicates are fine.
- Create one with a literal, with `var name: [Type] = []`, or with `Array(repeating:count:)`.
- Indexes start at 0. Valid indexes go from `0` to `count - 1`; `indices` is that range.
- A bad index crashes at runtime with `Index out of range`. Check `index >= 0 && index < array.count` first, or use `first` and `last` with `??`.
- `append`, `insert(_:at:)`, `remove(at:)`, `removeLast()` and subscript assignment change the array, and only work on a `var`.
