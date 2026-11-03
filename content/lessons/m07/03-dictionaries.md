---
id: m07-l03
title: "Dictionaries: looking things up by key"
description: You store values under keys, look them up, update and remove them, count how often things appear, and print a dictionary's contents in a stable order by sorting its keys.
module: m07
order: 3
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m07-l02]
objectives:
  - Create dictionaries with a literal and as an empty dictionary with a type annotation.
  - Look up a value by key and handle a missing key with ?? or the default subscript.
  - Add, update and remove entries.
  - Iterate over a dictionary in a stable order by sorting its keys.
  - Count how often each value appears in a collection.
terms:
  - term: Dictionary
    definition: "A collection that stores values under unique keys, with no defined order. The type of a dictionary from String keys to Int values is written [String: Int]."
  - term: Key
    definition: The value you look things up by. Every key in a dictionary is unique, and its type has to be Hashable.
  - term: Key-value pair
    definition: One entry in a dictionary, a key together with the value stored under it.
  - term: Frequency count
    definition: 'A dictionary that maps each distinct value to the number of times it appears, like ["a": 3, "b": 1].'
  - term: Hashable
    definition: A type whose values can be turned into a number used to find them quickly. Int, String, Double, Bool and Character are all Hashable.
mastery:
  - Write the type of a dictionary literal and declare an empty dictionary.
  - Read a value with dict[key] ?? fallback and explain why the subscript returns an optional.
  - Add, change and remove entries, and predict count afterward.
  - Print every entry of a dictionary in an order that doesn't change between runs.
  - "Write a frequency count with dict[key, default: 0] += 1."
resources: [swift-dictionary, swift-book-collection-types, swift-book-control-flow]
cards:
  - id: m07-l03-c1
    front: Why does scores["Ana"] return an optional?
    back: Because "Ana" might not be a key. The subscript returns the value if the key exists and nothing (nil) if it doesn't. Use ?? for a default until Module 8.
  - id: m07-l03-c2
    front: "What does counts[word, default: 0] += 1 do?"
    back: Reads the count for word, using 0 if the key is missing, adds 1 and stores the result under word. It's the standard way to count frequencies.
  - id: m07-l03-c3
    front: In what order does for (key, value) in dict visit the entries?
    back: No defined order. It can change between runs of the same program. For stable output, loop over dict.keys.sorted() instead.
  - id: m07-l03-c4
    front: How do you remove an entry from a dictionary?
    back: "Assign nil to its key (dict[key] = nil) or call dict.removeValue(forKey: key)."
---

## The idea in one sentence

A dictionary stores each value under a **key**, so you find it by asking for the key instead of searching for it.

## Why not an array?

Say you store country codes and capitals in two arrays, `codes = ["MX", "PE", "CO"]` and `capitals = ["Mexico City", "Lima", "Bogotá"]`. To find Peru's capital you search `codes` for `"PE"` with `firstIndex(of:)`, get 1, and read `capitals[1]`. That's a linear search every time, and the two arrays have to stay perfectly in step: one insert in the wrong place and every capital is wrong.

A dictionary keeps each code **with** its capital and goes straight to it.

## Creating a dictionary

**Plain definition:** a dictionary is a table with two columns, keys and values. Every key appears once.

**Precise definition:** `Dictionary<Key, Value>`, written `[Key: Value]`, is an unordered collection of key-value pairs. Keys are unique and their type must be `Hashable`; values can be any type and can repeat.

```swift
let capitals = ["MX": "Mexico City", "PE": "Lima", "CO": "Bogotá"]
var stock: [String: Int] = ["apples": 12, "pears": 0]
var visits: [String: Int] = [:]
print(capitals.count)
print(stock.count, visits.isEmpty)
```

```output
3
2 true
```

1. A **dictionary literal** is a list of `key: value` pairs in square brackets. Swift infers `[String: String]`.
2. The same with an annotation: `[String: Int]` reads "dictionary from String to Int".
3. `[:]` is the empty dictionary literal. Like `[]` for arrays, it needs a type annotation.
4. `count` is the number of pairs; `isEmpty` works as it does on arrays.

Notice this lesson never prints a whole dictionary with `print(capitals)`. That's on purpose, and you'll see why in a moment.

## Looking up a value

You read a value with a subscript, but the thing in brackets is a **key**, not a position:

```swift
let capitals = ["MX": "Mexico City", "PE": "Lima", "CO": "Bogotá"]
print(capitals["PE"] ?? "unknown")
print(capitals["AR"] ?? "unknown")
```

```output
Lima
unknown
```

Why the `??`? An array index is either valid or a crash. A dictionary key is different: asking for a key that isn't there is a perfectly normal question with a normal answer, "there's nothing under that key". So the subscript returns an **optional**: the value if the key exists, nothing if it doesn't. This returns an optional, and Module 8 covers it properly. For now, `??` supplies the value to use when the key is missing.

This is the first big difference from arrays: **a dictionary lookup never crashes.**

### A default right in the subscript

When the fallback is always the same, the subscript can take it directly:

```swift
let stock = ["apples": 12, "pears": 0]
print(stock["apples", default: 0])
print(stock["plums", default: 0])
```

```output
12
0
```

`stock["plums", default: 0]` returns a plain `Int`, not an optional. It reads like a sentence: "the stock of plums, or 0 if there's no entry". Its real power shows when you write through it, a few sections down.

## Adding, updating and removing

```swift
var stock = ["apples": 12, "pears": 0]
stock["plums"] = 30
stock["apples"] = 10
stock["pears"] = nil
print(stock.count)
print(stock["apples", default: 0], stock["plums", default: 0], stock["pears", default: -1])
let removed = stock.removeValue(forKey: "plums") ?? 0
print(removed, stock.count)
```

```output
2
10 30 -1
30 1
```

Line by line:

1. A `var` dictionary, so it can change.
2. Assigning to a key that **doesn't exist** adds a new pair.
3. Assigning to a key that **exists** replaces its value. Same syntax, so be careful with typos in keys: `stock["aples"] = 10` silently adds a new entry.
4. Assigning `nil` **removes** the pair. `nil` is Swift's word for "no value"; you'll meet it properly in Module 8.
5. Two pairs left: apples and plums.
6. `pears` is gone, so its lookup falls back to -1.
7. `removeValue(forKey:)` also removes, and returns the old value as an optional (nothing if the key wasn't there).
8. One pair left.

## Iteration order isn't stable

A dictionary doesn't keep its pairs in the order you wrote them. It stores them wherever its internal layout says, and in Swift that layout **changes from one run of the program to the next**. So this loop works, but the order of the lines it prints can be different every time you run it:

```swift illustrative
let stock = ["apples": 12, "pears": 4, "plums": 30]
for (fruit, count) in stock {
    print("\(fruit): \(count)")
}
// Possible output, in any order:
// plums: 30
// apples: 12
// pears: 4
```

This block is marked as not run by the course's tests, because its output can't be pinned down. The same goes for `print(stock)`: the brackets come out in a different order on different runs. In a test, a log you compare, or anything a user sees twice, that's a bug.

The fix is to **sort the keys** and look each one up:

```swift
let stock = ["pears": 4, "apples": 12, "plums": 30]
for fruit in stock.keys.sorted() {
    print("\(fruit): \(stock[fruit, default: 0])")
}
```

```output
apples: 12
pears: 4
plums: 30
```

`stock.keys` is every key, in the dictionary's unstable order. `sorted()` returns them as an **array** in ascending order, alphabetical for strings. That array has a fixed order, so the output does too. (Lesson 5 covers `sorted` in detail.)

A loop that only adds things up doesn't care about order. `stock.values` is every value:

```swift
let stock = ["pears": 4, "apples": 12, "plums": 30]
var totalFruit = 0
for count in stock.values {
    totalFruit += count
}
print(totalFruit)
```

```output
46
```

Whatever order the values come in, the sum is the same. **Rule of thumb:** if the order of the output depends on the order of iteration, sort first.

## Counting frequencies

Here's the pattern you'll use more than any other: count how many times each thing appears. Use the thing as the key and the count as the value.

```swift
let votes = ["pizza", "tacos", "pizza", "sushi", "tacos", "pizza"]
var counts: [String: Int] = [:]
for vote in votes {
    counts[vote, default: 0] += 1
}
for food in counts.keys.sorted() {
    print("\(food): \(counts[food, default: 0])")
}
```

```output
pizza: 3
sushi: 1
tacos: 2
```

`counts[vote, default: 0] += 1` does three things: reads the current count, using 0 if this is the first time `vote` shows up; adds 1; and stores the result under `vote`. Without the default subscript you'd write `counts[vote] = (counts[vote] ?? 0) + 1`, which does the same thing with more noise.

The trace for the first four votes:

| vote | count before | counts after |
| --- | --- | --- |
| pizza | 0 (missing) | pizza: 1 |
| tacos | 0 (missing) | pizza: 1, tacos: 1 |
| pizza | 1 | pizza: 2, tacos: 1 |
| sushi | 0 (missing) | pizza: 2, tacos: 1, sushi: 1 |

The same loop counts characters in a `String`, since a `String` is a sequence of `Character` values and `Character` is `Hashable`:

```swift
var letterCounts: [Character: Int] = [:]
for letter in "banana" {
    letterCounts[letter, default: 0] += 1
}
for letter in letterCounts.keys.sorted() {
    print(letter, letterCounts[letter, default: 0])
}
```

```output
a 3
b 1
n 2
```

### Finding the most common

To find the winner, loop over the **sorted** keys and keep the best so far. Sorting matters here too: with a tie, an unsorted loop could pick a different winner on each run.

```swift
let votes = ["tacos", "pizza", "sushi", "tacos", "pizza"]
var counts: [String: Int] = [:]
for vote in votes {
    counts[vote, default: 0] += 1
}

var winner = ""
var winnerVotes = 0
for food in counts.keys.sorted() {
    let votesForFood = counts[food, default: 0]
    if votesForFood > winnerVotes {
        winner = food
        winnerVotes = votesForFood
    }
}
print("\(winner) wins with \(winnerVotes) votes")
```

```output
pizza wins with 2 votes
```

Pizza and tacos both have 2. Because the keys are visited alphabetically and the comparison is strict (`>`), the alphabetically first one wins every time. That's a tie-breaking rule you can state and test, instead of an accident of memory layout.

Frequency counts are behind a big family of interview problems: anagrams, "first unique character", "most frequent element". A close cousin stores **positions** instead of counts: the [Two Sum](#/challenge/two-sum) challenge keeps a dictionary from each value seen so far to its index, so it can ask "have I already seen the number that completes this pair?" in one lookup instead of a second loop.

## A practical example: a price list

```swift
let prices = ["coffee": 45, "bread": 28, "juice": 35]
let order = ["coffee", "bread", "coffee", "cake"]

var total = 0
var unknownItems: [String] = []
for item in order {
    let price = prices[item, default: -1]
    if price < 0 {
        unknownItems.append(item)
    } else {
        total += price
    }
}
print("Total: \(total)")
print("Not on the menu: \(unknownItems)")
```

```output
Total: 118
Not on the menu: ["cake"]
```

The default here is -1, not 0, on purpose. A default of 0 would quietly add nothing for `"cake"` and hide the fact that it isn't on the menu; -1 is a sentinel no real price can have, so the program can tell the two cases apart. (Module 8 shows `if let`, which handles a missing key without a sentinel.) The order is an array, so it keeps its order and its duplicates; the price list is a dictionary, because you look prices up by name.

## Common mistakes

> [!error] error: value of optional type 'Int?' must be unwrapped to a value of type 'Int'
> You used `dict[key]` as a plain value, for example in arithmetic. The lookup returns an optional. Use `dict[key] ?? fallback` or `dict[key, default: fallback]`. Swift 6.3:

```swift no-compile value of optional type 'Int?' must be unwrapped to a value of type 'Int'
let scores = ["Ana": 90]
let curved = scores["Ana"] + 5
print(curved)
```

> [!error] Fatal error: Dictionary literal contains duplicate keys
> The same key appears twice in a literal. Swift 6.3 warns at compile time (`dictionary literal of type '[String : Int]' has duplicate entries for string literal key 'Ana'`) and crashes when the line runs:

```swift runtime-error Dictionary literal contains duplicate keys
print("Loading")
let ages = ["Ana": 30, "Luis": 25, "Ana": 31]
print(ages.count)
```

```output
Loading
```

> [!error] Printing a dictionary and expecting a fixed order
> `print(dict)` and `for (key, value) in dict` follow an order that can change between runs. Sort the keys first whenever order matters to the output.

> [!error] Expecting a typo to fail
> `stock["aples"] = 10` doesn't complain: it adds a new key. And `stock["aples"] ?? 0` silently gives 0. Keep keys in constants, or later in enums (Module 9), when they're used in more than one place.

> [!error] error: empty collection literal requires an explicit type
> `var counts = [:]` doesn't say what the keys and values are. Write `var counts: [String: Int] = [:]`.

````exercise
id: m07-l03-e1
type: comprehension
prompt: Which job is a dictionary the best fit for?
choices:
  - text: Storing the songs of a playlist in the order they'll play.
    correct: false
    why: Order matters and songs can repeat. That's an array.
  - text: Storing each username's last login date, to look it up by username.
    correct: true
    why: Unique keys (usernames), a value per key, and lookups by key.
  - text: Storing the last 10 temperatures read by a sensor.
    correct: false
    why: An ordered sequence of readings, possibly with repeats. An array.
  - text: Storing the third, fourth and fifth elements of a list.
    correct: false
    why: Positions are what arrays are for.
solution: |
  **The login dates by username.** A dictionary fits when each value has a unique name you'll look it up by, and the order of entries doesn't matter. Playlists and sensor readings are ordered and can repeat, which is what arrays are for.
````

````exercise
id: m07-l03-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  var seats = ["A1": "Ana", "A2": "Luis"]
  seats["A3"] = "Marta"
  seats["A1"] = "Sofía"
  seats["A2"] = nil
  print(seats.count)
  print(seats["A1"] ?? "empty")
  print(seats["A2"] ?? "empty")
  print(seats["B1", default: "no seat"])
  for seat in seats.keys.sorted() {
      print(seat, seats[seat] ?? "?")
  }
output: |
  2
  Sofía
  empty
  no seat
  A1 Sofía
  A3 Marta
hints:
  - Assigning to an existing key replaces the value; assigning nil removes the pair.
  - The keys are sorted as strings, alphabetically.
solution: |
  ```output
  2
  Sofía
  empty
  no seat
  A1 Sofía
  A3 Marta
  ```

  | Line | seats after |
  | --- | --- |
  | start | A1: Ana, A2: Luis |
  | `seats["A3"] = "Marta"` | A1: Ana, A2: Luis, A3: Marta |
  | `seats["A1"] = "Sofía"` | A1: Sofía, A2: Luis, A3: Marta |
  | `seats["A2"] = nil` | A1: Sofía, A3: Marta |

  Two pairs remain. A2 was removed, so its lookup gives the fallback. B1 never existed. The final loop visits A1 and A3 in sorted order, which is why the output is the same on every run.
````

````exercise
id: m07-l03-e3
type: fill-in
prompt: |
  Complete the program so it counts each number and prints exactly:

  ```output
  1: 2
  4: 1
  7: 3
  ```
code: |
  let rolls = [7, 1, 7, 4, 1, 7]
  var counts: [Int: Int] = [[1]]
  for roll in rolls {
      counts[roll, [[2]]: 0] += 1
  }
  for roll in counts.keys.[[3]]() {
      print("\(roll): \(counts[roll, default: 0])")
  }
blanks:
  - id: "1"
    answers: ["[:]"]
  - id: "2"
    answers: ["default"]
  - id: "3"
    answers: ["sorted"]
solution: |
  ```swift
  let rolls = [7, 1, 7, 4, 1, 7]
  var counts: [Int: Int] = [:]
  for roll in rolls {
      counts[roll, default: 0] += 1
  }
  for roll in counts.keys.sorted() {
      print("\(roll): \(counts[roll, default: 0])")
  }
  ```

  ```output
  1: 2
  4: 1
  7: 3
  ```

  `[:]` is the empty dictionary. The `default:` subscript starts each new key at 0 before adding 1. Sorting the keys gives 1, 4, 7 in that order every time; without it, the three lines could come out in any order.
````

````exercise
id: m07-l03-e4
type: find-errors
prompt: This program should count words and print each count. Pick out the real problems.
code: |
  let words = ["red", "blue", "red"]
  var counts = [:]
  for word in words {
      counts[word] += 1
  }
  for (word, count) in counts {
      print(word, count)
  }
choices:
  - text: "Line 2: the empty dictionary has no type."
    correct: true
    why: "empty collection literal requires an explicit type. It should be [String: Int]."
  - text: "Line 4: counts[word] is an optional, so += 1 doesn't compile."
    correct: true
    why: "The lookup may find nothing. Use counts[word, default: 0] += 1."
  - text: "Lines 6 and 7 print the pairs in an order that can change between runs."
    correct: true
    why: "It compiles and runs, but the output isn't stable. Loop over counts.keys.sorted()."
  - text: "Line 3: you can't loop over an array of strings."
    correct: false
    why: "for word in words is fine."
rubric:
  - I gave the dictionary an explicit type.
  - I used the default subscript to count.
  - I sorted the keys so the output is stable.
  - My version prints blue 1 then red 2.
solution: |
  ```swift
  let words = ["red", "blue", "red"]
  var counts: [String: Int] = [:]
  for word in words {
      counts[word, default: 0] += 1
  }
  for word in counts.keys.sorted() {
      print(word, counts[word, default: 0])
  }
  ```

  ```output
  blue 1
  red 2
  ```

  The first two problems stop the program from compiling. The third is worse in a way: the program runs and looks right, until one day the lines come out in a different order and a test that compares output fails for no visible reason.
````

````exercise
id: m07-l03-e5
type: solve
prompt: |
  Write `func firstUniqueLetter(in word: String) -> String` that returns the first letter that appears exactly once in `word`, as a `String`, or `"none"` if every letter repeats. Then print the results for `"swiss"`, `"level"`, `"aabb"` and `""`:

  ```output
  w
  v
  none
  none
  ```
starter: |
  func firstUniqueLetter(in word: String) -> String {
      // Your code
      return "none"
  }
hints:
  - "Two passes. First count every letter in a [Character: Int] dictionary."
  - Then loop over the word again, in order, and return the first letter whose count is 1. String(letter) turns a Character into a String.
rubric:
  - I counted letters with a dictionary in one pass.
  - The second pass goes through the word in its original order, not through the dictionary.
  - The function returns "none" for a word with no unique letters and for an empty word.
  - I can explain why looping over the dictionary would give the wrong or an unstable answer.
solution: |
  ```swift
  func firstUniqueLetter(in word: String) -> String {
      var counts: [Character: Int] = [:]
      for letter in word {
          counts[letter, default: 0] += 1
      }
      for letter in word {
          if counts[letter, default: 0] == 1 {
              return String(letter)
          }
      }
      return "none"
  }

  print(firstUniqueLetter(in: "swiss"))
  print(firstUniqueLetter(in: "level"))
  print(firstUniqueLetter(in: "aabb"))
  print(firstUniqueLetter(in: ""))
  ```

  ```output
  w
  v
  none
  none
  ```

  The first pass builds the counts: for `"swiss"`, s: 3, w: 1, i: 1. The second pass walks the **word**, not the dictionary, because "first" refers to the word's order. In `"swiss"`, both w and i appear once, and w comes first. Looping over the dictionary instead could return either one, and might change between runs. Each pass is N steps, so the whole function is about 2N, much better than counting each letter by scanning the whole word again (N × N).
````

````exercise
id: m07-l03-e6
type: design
prompt: |
  A library app needs to store, for each book's ISBN (a `String`), how many copies are on the shelf. Users search by ISBN, the librarian adds and removes copies, and once a day the app prints a report of every book and its copies. Describe the data structure and how each operation works, including what happens with an ISBN that isn't in the system.
rubric:
  - "I chose a [String: Int] dictionary keyed by ISBN and said why an array of pairs is worse."
  - Search uses the subscript with a default or ?? and says what a missing ISBN shows.
  - Adding and removing copies use the subscript, and I decided what happens when copies reach 0.
  - The daily report sorts the keys so it prints in the same order every day.
solution: |
  A dictionary `var copies: [String: Int]`, keyed by ISBN. Every operation is a lookup by ISBN, and each ISBN is unique, which is exactly what a dictionary is for. An array of `(isbn, count)` tuples would need a linear search for every lookup and would let the same ISBN appear twice by mistake.

  - **Search:** `copies[isbn, default: 0]`. A missing ISBN shows 0 copies. If the app needs to tell "not in the catalog" apart from "all copies checked out", it should use `copies[isbn]` and handle the missing case separately (with `if let`, Module 8), since the default would hide the difference.
  - **Add a copy:** `copies[isbn, default: 0] += 1`. Works for new and existing ISBNs.
  - **Remove a copy:** check that the count is above 0 first, then subtract 1. Decide whether a book with 0 copies stays in the dictionary (it's still in the catalog) or is removed with `copies[isbn] = nil` (it's gone). Keeping it at 0 is usually right for a library.
  - **Daily report:** `for isbn in copies.keys.sorted()`, so the report comes out in the same order every day and two reports can be compared line by line.
````

## Summary

- A dictionary, `[Key: Value]`, stores values under unique keys. Create an empty one with `var d: [String: Int] = [:]`.
- `dict[key]` returns an optional, because the key might be missing. Use `?? fallback` or `dict[key, default: fallback]`. A lookup never crashes.
- Assigning to a key adds or replaces; assigning `nil` or calling `removeValue(forKey:)` removes.
- Iteration order isn't defined and changes between runs. Loop over `dict.keys.sorted()` when order matters.
- `counts[item, default: 0] += 1` counts frequencies. It's behind a whole family of interview problems.
