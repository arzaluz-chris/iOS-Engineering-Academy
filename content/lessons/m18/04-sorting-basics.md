---
id: m18-l04
title: Sorting basics and Swift's sort
description: You learn the vocabulary of sorting (comparison sorts, stability, in place), write insertion sort as the simple baseline and measure when it's fast, read exactly what Apple's documentation guarantees about sort() and sorted(by:), see what a comparator that isn't a strict weak ordering does, and sort by several keys with tuples, mixed directions and chained stable sorts.
module: m18
order: 4
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m18-l03]
objectives:
  - Define a comparison sort, a stable sort and an in-place sort, and give an example of each property mattering.
  - Implement insertion sort, count its comparisons, and explain why it's O(n²) in general and fast on nearly sorted input.
  - State what Apple's documentation guarantees for sort(), sort(by:), sorted() and sorted(by:), and what it doesn't say.
  - Check a comparator against the three strict weak ordering rules and recognize the symptoms of breaking them.
  - Sort by several keys with tuple comparison, with mixed ascending and descending keys, and with chained stable sorts.
terms:
  - term: Comparison sort
    definition: A sorting algorithm that learns about the order only by asking "should a come before b?" Every such algorithm needs on the order of n log n comparisons in the worst case.
  - term: Stable sort
    definition: A sort that keeps elements that compare as equal in the same relative order they had before sorting.
  - term: In-place sort
    definition: A sort that rearranges the elements inside the original storage, using only a small amount of extra memory.
  - term: Insertion sort
    definition: A sort that grows a sorted prefix one element at a time, shifting larger elements right to make room for each new one. O(n²) in the worst case, O(n) on sorted input, stable.
  - term: Strict weak ordering
    definition: "The rules a sort predicate must follow: never a before a; if a before b and b before c, then a before c; and if a ties b and b ties c, then a ties c."
mastery:
  - Say whether a given sort result could come from a stable sort.
  - Write insertion sort and predict its comparison count on sorted and reversed input.
  - Quote the two guarantees Apple documents for Swift's sort, and say that the docs don't name the algorithm.
  - Spot a comparator built with <= or with && across two keys, and fix it.
  - Write a comparator for "in stock first, then cheapest, then by name".
resources: [swift-array-sort, swift-array-sorted-by, swift-comparable, swift-array, swift-book-closures]
cards:
  - id: m18-l04-c1
    front: What does it mean for a sort to be stable?
    back: Elements that compare as equal keep their original relative order. Sorting tasks by priority with a stable sort leaves tasks of the same priority in the order they were added.
  - id: m18-l04-c2
    front: What does Apple's documentation guarantee about Swift's sort() and sorted(by:)?
    back: "\"The sorting algorithm is guaranteed to be stable\" and the complexity is \"O(n log n), where n is the length of the collection\" (or sequence). It doesn't name the algorithm."
  - id: m18-l04-c3
    front: What are the three rules of a strict weak ordering?
    back: "Irreflexivity: areInIncreasingOrder(a, a) is false. Transitive comparability: a before b and b before c means a before c. Transitive incomparability: if a ties b and b ties c, then a ties c."
  - id: m18-l04-c4
    front: "Why is sorted(by: <=) wrong?"
    back: "<= returns true for equal elements, which breaks irreflexivity. The docs require a strict weak ordering and don't say what happens otherwise; in a Swift 6.3 run, ties came out reversed, so the sort was no longer stable."
  - id: m18-l04-c5
    front: How do you sort by score descending, then name ascending, in one comparator?
    back: "sorted { ($1.score, $0.name) < ($0.score, $1.name) }. Swapping which side each score comes from flips that key's direction. Or write it out: if a.score != b.score { return a.score > b.score }; return a.name < b.name."
---

## The idea in one sentence

In real code you almost never write a sorting algorithm; you call `sort()` or `sorted(by:)` and spend your care on **the comparator**, which has to follow rules the sort relies on, and on knowing what the standard library promises.

Module 7 introduced `sorted()`, `sorted(by:)` and tie-breakers, and Module 10 the rules for `Comparable`. This lesson adds the vocabulary to talk about sorts, a baseline algorithm, and the precise contract.

## Three words

**Comparison sort.** The algorithm learns about the order only through a yes/no question: should `a` come before `b`? `sorted(by:)` is one: your closure is that question. A proven result says any comparison sort needs about n log₂ n comparisons in the worst case (it has to tell apart all n! possible orders, and each yes/no answer at best halves the possibilities). So O(n log n) is the best a comparison sort can do. Sorts that don't compare, like counting how many times each small integer appears, can beat it on special data.

**Stable.** Elements that compare as equal stay in their original relative order:

```swift
struct Task {
    let title: String
    let priority: Int
}

let tasks = [
    Task(title: "Fix login", priority: 2),
    Task(title: "Update icon", priority: 1),
    Task(title: "Review PR", priority: 2),
    Task(title: "Write tests", priority: 1),
    Task(title: "Ship build", priority: 2),
]

let byPriority = tasks.sorted { $0.priority < $1.priority }
for task in byPriority {
    print(task.priority, task.title)
}
```

```output
1 Update icon
1 Write tests
2 Fix login
2 Review PR
2 Ship build
```

The comparator only looks at priority, so "Update icon" and "Write tests" are ties. A stable sort keeps them in the order they were added; an unstable sort could print them either way. Stability matters whenever the original order means something: creation time, a previous sort, the order the server sent.

**In place.** The sort rearranges the original storage and needs little extra memory. `sort()` sorts the array you call it on; `sorted()` returns a new array. Whether the algorithm behind them uses extra memory internally is a separate question, and Apple's documentation doesn't answer it.

## Insertion sort: the baseline

Insertion sort is the way most people sort a hand of cards: keep the left part sorted, take the next card, and slide it left past every bigger card.

```swift
func insertionSort(_ values: inout [Int]) {
    guard values.count > 1 else {
        return
    }
    for i in 1..<values.count {
        let current = values[i]
        var j = i - 1
        while j >= 0 && values[j] > current {
            values[j + 1] = values[j]
            j -= 1
        }
        values[j + 1] = current
        print("after inserting \(current): \(values)")
    }
}

var hand = [5, 2, 4, 6, 1, 3]
insertionSort(&hand)
```

```output
after inserting 2: [2, 5, 4, 6, 1, 3]
after inserting 4: [2, 4, 5, 6, 1, 3]
after inserting 6: [2, 4, 5, 6, 1, 3]
after inserting 1: [1, 2, 4, 5, 6, 3]
after inserting 3: [1, 2, 3, 4, 5, 6]
```

- The **invariant**: before pass `i`, `values[0..<i]` is sorted. Each pass inserts `values[i]` into it, so after the last pass everything is.
- `current` is saved first, because shifting overwrites `values[i]`.
- `while j >= 0 && values[j] > current` shifts every bigger element one place right. Order matters in that condition: `j >= 0` has to be checked before `values[j]` is read.
- The comparison is **`>`, not `>=`**: an element equal to `current` is not shifted past, so equal elements keep their order. That's what makes insertion sort stable.
- The `guard` handles the empty array: `1..<0` isn't a valid range and would crash.

How fast it is depends on how sorted the input already is. Counting comparisons and shifts on 1,000 elements:

```swift
func insertionSortCounting(_ values: inout [Int]) -> (comparisons: Int, shifts: Int) {
    var comparisons = 0
    var shifts = 0
    guard values.count > 1 else {
        return (0, 0)
    }
    for i in 1..<values.count {
        let current = values[i]
        var j = i - 1
        while j >= 0 {
            comparisons += 1
            if values[j] <= current {
                break
            }
            values[j + 1] = values[j]
            shifts += 1
            j -= 1
        }
        values[j + 1] = current
    }
    return (comparisons, shifts)
}

var sorted = Array(0..<1_000)
print("sorted:       ", insertionSortCounting(&sorted))

var nearlySorted = Array(0..<1_000)
nearlySorted.swapAt(10, 11)
nearlySorted.swapAt(500, 503)
print("nearly sorted:", insertionSortCounting(&nearlySorted))

var shuffled = (0..<1_000).map { ($0 * 7_919) % 1_000 }
print("shuffled:     ", insertionSortCounting(&shuffled))

var reversed = Array((0..<1_000).reversed())
print("reversed:     ", insertionSortCounting(&reversed))
```

```output
sorted:        (comparisons: 999, shifts: 0)
nearly sorted: (comparisons: 1005, shifts: 6)
shuffled:      (comparisons: 251100, shifts: 250101)
reversed:      (comparisons: 499500, shifts: 499500)
```

(`(i * 7_919) % 1_000` is a cheap way to scramble 0…999 into a fixed order, so the output is the same on every run. 7,919 shares no factor with 1,000, so every number appears once.)

- **Sorted:** one comparison per element, no shifts. **O(n).**
- **Reversed:** every element slides all the way left: n(n − 1) / 2, the triangle from Module 15. **O(n²).**
- **Shuffled:** about half of that, n²/4. Still O(n²).
- **Nearly sorted:** shifts equal the number of out-of-order pairs, so a few swaps cost a few shifts. That's insertion sort's real strength: it's O(n + number of out-of-order pairs).

Insertion sort is stable, in place, simple, and quick on small or nearly sorted arrays. Library sorts commonly use it, or something like it, for short runs inside a bigger algorithm. For large arbitrary input, O(n²) rules it out; lessons 5 and 6 cover the O(n log n) sorts.

## What Swift's sort guarantees

Apple's documentation for `Array`'s `sort()`, `sort(by:)`, `sorted()` and `sorted(by:)` states two guarantees, in these words:

- "The sorting algorithm is guaranteed to be stable."
- Complexity: "O(n log n), where n is the length of the collection" (for `sorted`, "of the sequence").

That's the contract. The documentation doesn't name the algorithm, and it says nothing about how much extra memory sorting uses. Swift's implementation is open source and has changed between versions, which is a good reason to rely on the documented guarantees and not on whatever the current algorithm happens to be.

The four methods, side by side:

| Method | Works on | Returns | Order |
| --- | --- | --- | --- |
| `sort()` | a mutable collection with `Comparable` elements, like a `var` array | nothing; sorts in place | ascending, by `<` |
| `sort(by:)` | a mutable collection | nothing; sorts in place | your predicate |
| `sorted()` | any sequence with `Comparable` elements (arrays, sets, dictionary keys…) | a new `[Element]` | ascending, by `<` |
| `sorted(by:)` | any sequence | a new `[Element]` | your predicate |

The docs also say that calling `sorted()` "is equivalent to calling this method and passing the less-than operator (`<`) as the predicate." `sorted()` on a `Set` is how you get a predictable order out of something unordered.

### The rules your predicate must follow

From the same documentation: the predicate "must be a strict weak ordering over the elements. That is, for any elements `a`, `b`, and `c`, the following conditions must hold":

1. "`areInIncreasingOrder(a, a)` is always `false`. (Irreflexivity)"
2. "If `areInIncreasingOrder(a, b)` and `areInIncreasingOrder(b, c)` are both `true`, then `areInIncreasingOrder(a, c)` is also `true`. (Transitive comparability)"
3. "Two elements are incomparable if neither is ordered before the other according to the predicate. If `a` and `b` are incomparable, and `b` and `c` are incomparable, then `a` and `c` are also incomparable. (Transitive incomparability)"

"Incomparable" means **tied**: neither goes first. Rule 3 says ties have to behave like equality. It's "weak" because, unlike `Comparable`'s strict total order from Module 10, two different elements are allowed to tie (two tasks with the same priority aren't equal, but the predicate can't tell them apart). The docs also define stability in those terms: a stable sort "preserves the relative order of elements for which `areInIncreasingOrder` does not establish an order."

### What breaks with a bad comparator

The most common way to break the rules is `<=`. It returns `true` for an element compared with itself, which violates rule 1:

```swift
struct Task {
    let title: String
    let priority: Int
}

let tasks = [
    Task(title: "Fix login", priority: 2),
    Task(title: "Update icon", priority: 1),
    Task(title: "Review PR", priority: 2),
    Task(title: "Write tests", priority: 1),
    Task(title: "Ship build", priority: 2),
]

let correct = tasks.sorted { $0.priority < $1.priority }
let broken = tasks.sorted { $0.priority <= $1.priority }
print(correct.map { $0.title })
print(broken.map { $0.title })
```

```output
["Update icon", "Write tests", "Fix login", "Review PR", "Ship build"]
["Write tests", "Update icon", "Ship build", "Review PR", "Fix login"]
```

The numbers are still in order, but every group of ties came out **reversed**. With `<=`, "Review PR" claims to belong before "Fix login" and "Fix login" claims to belong before "Review PR", and the stable sort's promise about ties no longer has anything to hold on to.

That reversal is what Swift 6.3 did with this input. The documentation states the requirement and doesn't say what happens if you break it, so don't read the output as a rule: a different input, a different comparator or a future Swift could give a different wrong answer. The safe assumption is "the result is unspecified". A comparator that breaks transitivity, like rock-paper-scissors, has no correct sorted order at all, and the result depends on which pairs the algorithm happened to compare.

How to check a comparator quickly:

- Does it return `false` when both arguments are the same element? (Rules out `<=` and `>=`.)
- For multiple keys, does it compare the second key **only when the first ties**? (Rules out `a.x < b.x && a.y < b.y`, the Module 10 trap.)
- Is it computed only from the two elements? (A comparator that reads a random number or a value that changes during the sort can't be consistent.)

## Sorting by several keys

### Tuples

Swift's standard library defines `<` for tuples of up to six `Comparable` elements, comparing them left to right and moving to the next element only on a tie. That's exactly a multi-key comparison:

```swift
struct Player {
    let name: String
    let level: Int
    let score: Int
}

let players = [
    Player(name: "Marta", level: 2, score: 300),
    Player(name: "Ana", level: 3, score: 150),
    Player(name: "Diego", level: 2, score: 450),
    Player(name: "Luis", level: 3, score: 150),
    Player(name: "Bea", level: 2, score: 300),
]

let byLevelThenName = players.sorted { ($0.level, $0.name) < ($1.level, $1.name) }
print(byLevelThenName.map { "\($0.level) \($0.name)" })

let byScoreDescThenName = players.sorted { ($1.score, $0.name) < ($0.score, $1.name) }
print(byScoreDescThenName.map { "\($0.score) \($0.name)" })
```

```output
["2 Bea", "2 Diego", "2 Marta", "3 Ana", "3 Luis"]
["450 Diego", "300 Bea", "300 Marta", "150 Ana", "150 Luis"]
```

For a **descending** key, swap which element it comes from. In `($1.score, $0.name) < ($0.score, $1.name)`, the scores are compared as `$1.score < $0.score` (descending) and, on a tie, the names as `$0.name < $1.name` (ascending). It's compact and easy to get wrong when you read it six months later; the explicit version is longer and obvious:

```swift
struct Player {
    let name: String
    let level: Int
    let score: Int
}

let players = [
    Player(name: "Marta", level: 2, score: 300),
    Player(name: "Ana", level: 3, score: 150),
    Player(name: "Diego", level: 2, score: 450),
]

let ranking = players.sorted { a, b in
    if a.score != b.score {
        return a.score > b.score
    }
    return a.name < b.name
}
print(ranking.map { $0.name })
```

```output
["Diego", "Marta", "Ana"]
```

Both are strict weak orderings: each key is compared with a strict operator, and later keys only matter on a tie.

> [!error] error: binary operator '<' cannot be applied to two '(Bool, Int)' operands
> Every element of the tuple has to be `Comparable`, and `Bool` isn't. Neither are optionals. Map them to something that is, like `isInStock ? 0 : 1`, or compare them separately. Tuples with seven or more elements don't have `<` either.

```swift no-compile binary operator '<' cannot be applied to two '(Bool, Int)' operands
let a = (true, 10)
let b = (false, 5)
print(a < b)
```

### Chaining stable sorts

Because the sort is stable, you can also sort by the **least important key first** and the most important key last:

```swift
struct Player {
    let name: String
    let level: Int
    let score: Int
}

let players = [
    Player(name: "Marta", level: 2, score: 300),
    Player(name: "Ana", level: 3, score: 150),
    Player(name: "Diego", level: 2, score: 450),
    Player(name: "Luis", level: 3, score: 150),
    Player(name: "Bea", level: 2, score: 300),
]

let chained = players
    .sorted { $0.name < $1.name }
    .sorted { $0.level < $1.level }
print(chained.map { "\($0.level) \($0.name)" })
```

```output
["2 Bea", "2 Diego", "2 Marta", "3 Ana", "3 Luis"]
```

The second sort only reorders by level and keeps ties (same level) in the order the first sort left them: by name. That's the behavior of clicking column headers in a spreadsheet: the previous order survives as a tie-breaker. It does one full sort per key, so a single comparator is cheaper; chaining is useful when the keys are chosen at runtime, like a user tapping sort options. It only works because Swift's sort is documented as stable.

## A practical example: a product list

A shop screen lists products: in stock first, then cheapest first, then alphabetically, case-insensitively.

```swift
struct Product {
    let name: String
    let price: Int
    let isInStock: Bool
}

let products = [
    Product(name: "cable", price: 12, isInStock: true),
    Product(name: "Charger", price: 25, isInStock: false),
    Product(name: "Case", price: 12, isInStock: true),
    Product(name: "adapter", price: 9, isInStock: false),
    Product(name: "Battery", price: 25, isInStock: true),
]

let listed = products.sorted { a, b in
    let aKey = (a.isInStock ? 0 : 1, a.price, a.name.lowercased())
    let bKey = (b.isInStock ? 0 : 1, b.price, b.name.lowercased())
    return aKey < bKey
}
for product in listed {
    print(product.isInStock ? "in stock " : "sold out ", product.price, product.name)
}
```

```output
in stock  12 cable
in stock  12 Case
in stock  25 Battery
sold out  9 adapter
sold out  25 Charger
```

- `isInStock ? 0 : 1` makes the `Bool` comparable and puts `true` first.
- `lowercased()` keeps "cable" and "Case" together; plain string comparison would put every uppercase letter before every lowercase one (Module 7).
- Each comparison builds two small tuples and lowercases two names. For a list a person scrolls through, that's fine. For hundreds of thousands of elements, compute the keys once (`map` to `(key, product)` pairs, sort, `map` back), since the comparator runs O(n log n) times.

For names shown to people, Foundation has locale-aware comparisons such as `localizedStandardCompare(_:)`, which Apple's documentation describes as comparing strings "as sorted by the Finder" and says may change between releases. In the test container it sorted `["file10", "file2", "File1"]` as `["File1", "file2", "file10"]`: numbers by value, case ignored. This lesson sticks to the standard library.

## Common mistakes

> [!error] Using <= or >= as the predicate
> It breaks irreflexivity. The output may look sorted while ties come out in a different order, so the bug survives every test that has no ties.

> [!error] Combining keys with &&
> `a.level < b.level && a.score < b.score` makes many pairs neither less nor greater without being ties of the first key, which breaks transitive incomparability. Compare the second key only when the first is equal.

> [!error] Expecting a stable result from your own sort
> `sort()` and `sorted(by:)` are documented as stable. A hand-written quicksort (lesson 6) isn't, unless you made it so. If the order of ties matters, say so in a test.

> [!error] Writing insertion sort with >= in the shift condition
> `while j >= 0 && values[j] >= current` still sorts, but it moves equal elements past each other, so it's no longer stable, and it does extra shifts on runs of equal values.

## Exercises

````exercise
id: m18-l04-e1
type: comprehension
prompt: |
  Messages arrive in this order: `(alice, 10:02)`, `(bob, 10:01)`, `(alice, 10:00)`, `(bob, 10:03)`. You sort them by sender only. Which result can a stable sort produce?
choices:
  - text: "(alice, 10:02), (alice, 10:00), (bob, 10:01), (bob, 10:03)"
    correct: true
    why: "The alice messages keep their arrival order (10:02 before 10:00), and so do the bob messages."
  - text: "(alice, 10:00), (alice, 10:02), (bob, 10:01), (bob, 10:03)"
    correct: false
    why: "That's sorted by sender then time. A stable sort by sender alone keeps ties in arrival order, and 10:02 arrived first."
  - text: "Either of the first two, depending on the algorithm."
    correct: false
    why: "Any unstable sort could produce either. A stable sort has exactly one possible result."
  - text: "(bob, 10:01), (bob, 10:03), (alice, 10:02), (alice, 10:00)"
    correct: false
    why: "Sorting by sender ascending puts alice first."
solution: |
  **The first one.** The comparator says nothing about time, so the two alice messages tie, and a stable sort leaves them in arrival order: 10:02, then 10:00. The second answer is what you'd get by sorting by `(sender, time)`, which is a different comparator. A stable sort is deterministic: for a given input and comparator, there's exactly one stable result.
````

````exercise
id: m18-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  var values = [3, 1, 2, 1]
  var shifts = 0
  for i in 1..<values.count {
      let current = values[i]
      var j = i - 1
      while j >= 0 && values[j] > current {
          values[j + 1] = values[j]
          shifts += 1
          j -= 1
      }
      values[j + 1] = current
      print(values)
  }
  print("shifts: \(shifts)")
output: |
  [1, 3, 2, 1]
  [1, 2, 3, 1]
  [1, 1, 2, 3]
  shifts: 4
hints:
  - "Each pass inserts values[i] into the sorted prefix values[0..<i]."
  - "The last 1 slides past 3 and 2, but not past the first 1, because 1 > 1 is false."
solution: |
  ```output
  [1, 3, 2, 1]
  [1, 2, 3, 1]
  [1, 1, 2, 3]
  shifts: 4
  ```

  - Pass 1: insert 1 into `[3]`. 3 shifts right: 1 shift.
  - Pass 2: insert 2 into `[1, 3]`. 3 shifts right; 1 > 2 is false, so it stops: 1 shift.
  - Pass 3: insert the second 1 into `[1, 2, 3]`. 3 and 2 shift right; 1 > 1 is false, so it stops right after the first 1: 2 shifts.

  4 shifts in total. The two 1s stay in their original order (the one that started at index 1 is still first), which is the stability that `>` buys.
````

````exercise
id: m18-l04-e3
type: fill-in
prompt: Complete the comparator so that tasks sort by due day ascending, then by priority descending (higher first), then by title ascending, using one tuple comparison.
code: |
  struct Task {
      let title: String
      let dueDay: Int
      let priority: Int
  }

  let ordered = tasks.sorted { a, b in
      (a.dueDay, [[1]], a.title) < (b.dueDay, [[2]], [[3]])
  }
blanks:
  - id: "1"
    answers: ["b.priority"]
  - id: "2"
    answers: ["a.priority"]
  - id: "3"
    answers: ["b.title"]
solution: |
  Priority is the descending key, so its sides are swapped: `b.priority` on the left, `a.priority` on the right. Everything else keeps `a` on the left.

  ```swift
  struct Task {
      let title: String
      let dueDay: Int
      let priority: Int
  }

  let tasks = [
      Task(title: "Invoice", dueDay: 2, priority: 1),
      Task(title: "Backup", dueDay: 1, priority: 1),
      Task(title: "Deploy", dueDay: 2, priority: 3),
      Task(title: "Audit", dueDay: 2, priority: 3),
      Task(title: "Email", dueDay: 1, priority: 2),
  ]

  let ordered = tasks.sorted { a, b in
      (a.dueDay, b.priority, a.title) < (b.dueDay, a.priority, b.title)
  }
  for task in ordered {
      print(task.dueDay, task.priority, task.title)
  }
  ```

  ```output
  1 2 Email
  1 1 Backup
  2 3 Audit
  2 3 Deploy
  2 1 Invoice
  ```

  Day 1 comes first; within it, priority 2 before 1. On day 2, the two priority-3 tasks tie and fall back to the title. If this reads as too clever, the `if … != … { return … }` chain is the same ordering.
````

````exercise
id: m18-l04-e4
type: find-errors
prompt: |
  A leaderboard should show players by score, highest first, and players with the same score in the order they joined (the array's order). Which statements about this code are true?
code: |
  struct Entry {
      let name: String
      let score: Int
  }

  func leaderboard(_ entries: [Entry]) -> [Entry] {
      entries.sorted { $0.score >= $1.score }
  }
choices:
  - text: ">= returns true when an entry is compared with itself, so the predicate isn't a strict weak ordering."
    correct: true
    why: "Irreflexivity requires areInIncreasingOrder(a, a) to be false."
  - text: "Changing >= to > fixes it, and ties keep the joining order because the sort is stable."
    correct: true
    why: "> is a strict weak ordering, and sorted(by:) is documented as stable, so equal scores keep their array order."
  - text: "With >=, the documented stability still keeps tied players in joining order."
    correct: false
    why: "Stability is defined for elements the predicate doesn't order. With >=, ties are ordered both ways, and the docs don't say what happens when the predicate isn't a strict weak ordering. In the lesson's run, ties came out reversed."
  - text: "It needs a second key, the name, to be correct."
    correct: false
    why: "The requirement is joining order for ties, which stability gives for free. Adding the name would change the requirement."
rubric:
  - I identified >= as breaking irreflexivity.
  - I fixed it with > and relied on documented stability for the ties.
  - I noted that the docs don't specify what a bad predicate does, so the only safe fix is a valid one.
solution: |
  Use `>`:

  ```swift
  struct Entry {
      let name: String
      let score: Int
  }

  func leaderboard(_ entries: [Entry]) -> [Entry] {
      entries.sorted { $0.score > $1.score }
  }

  let entries = [
      Entry(name: "Ana", score: 80),
      Entry(name: "Luis", score: 95),
      Entry(name: "Marta", score: 80),
      Entry(name: "Diego", score: 95),
  ]
  print(leaderboard(entries).map { $0.name })
  ```

  ```output
  ["Luis", "Diego", "Ana", "Marta"]
  ```

  Luis joined before Diego and Ana before Marta, and they stay that way. With `>=`, the lesson's run reversed groups of ties, and since Apple's documentation only states that the predicate must be a strict weak ordering, without saying what happens otherwise, any output from the broken version is unspecified. A test with tied scores catches this; a test without ties doesn't.
````

````exercise
id: m18-l04-e5
type: solve
prompt: |
  Write `func sortedContacts(_ contacts: [Contact]) -> [Contact]` for `struct Contact { let first: String; let last: String }`. Order: by last name, ignoring case; then by first name, ignoring case. Contacts with an empty last name go at the end, ordered by first name.

  Print `"\(first) \(last)"` for each contact in this input:
  `("ana", "Ortiz")`, `("Luis", "")`, `("Bea", "ortiz")`, `("Carlos", "Diaz")`, `("Ada", "")`, `("diego", "Diaz")`.

  ```output
  ["Carlos Diaz", "diego Diaz", "ana Ortiz", "Bea ortiz", "Ada ", "Luis "]
  ```
starter: |
  struct Contact {
      let first: String
      let last: String
  }

  func sortedContacts(_ contacts: [Contact]) -> [Contact] {
      contacts.sorted { a, b in
          // Build a comparable key for each contact
          false
      }
  }
hints:
  - "A key like (last.isEmpty ? 1 : 0, last.lowercased(), first.lowercased()) does all three rules."
  - "Bool isn't Comparable, so turn isEmpty into 0 or 1."
rubric:
  - The comparator is a strict weak ordering built from a tuple or from if/else with strict comparisons.
  - Empty last names sort last, and case doesn't affect the order.
  - The output matches.
solution: |
  ```swift
  struct Contact {
      let first: String
      let last: String
  }

  func sortedContacts(_ contacts: [Contact]) -> [Contact] {
      contacts.sorted { a, b in
          let aKey = (a.last.isEmpty ? 1 : 0, a.last.lowercased(), a.first.lowercased())
          let bKey = (b.last.isEmpty ? 1 : 0, b.last.lowercased(), b.first.lowercased())
          return aKey < bKey
      }
  }

  let contacts = [
      Contact(first: "ana", last: "Ortiz"),
      Contact(first: "Luis", last: ""),
      Contact(first: "Bea", last: "ortiz"),
      Contact(first: "Carlos", last: "Diaz"),
      Contact(first: "Ada", last: ""),
      Contact(first: "diego", last: "Diaz"),
  ]
  print(sortedContacts(contacts).map { "\($0.first) \($0.last)" })
  ```

  ```output
  ["Carlos Diaz", "diego Diaz", "ana Ortiz", "Bea ortiz", "Ada ", "Luis "]
  ```

  The first element of the key moves empty last names to the end. The second compares last names without case, so "Ortiz" and "ortiz" tie and fall through to first names. The third breaks that tie, also without case, which is why "ana" comes before "Bea" even though uppercase letters sort before lowercase ones. Two contacts with identical keys would keep their input order, because the sort is stable.
````

````exercise
id: m18-l04-e6
type: explain
prompt: |
  A table view lets the user tap "Name" and then "Team". The code sorts the current rows by name when "Name" is tapped, and then sorts that result by team when "Team" is tapped. The user sees teams in order, with each team's members alphabetized. Explain why that works, what property it depends on, and what the user would see if the sort weren't stable.
code: |
  // "Name" tapped
  rows.sort { $0.name < $1.name }

  // then "Team" tapped
  rows.sort { $0.team < $1.team }
rubric:
  - I explained that the second sort only orders by team and leaves ties (same team) in their current order, which is alphabetical from the first sort.
  - I named stability as the property, and noted that Swift documents sort() and sorted(by:) as stable.
  - I described the unstable outcome as teams in order but members in an arbitrary order within each team.
solution: |
  After the first tap, the rows are alphabetical. The second sort's predicate only compares teams, so all the members of one team are ties. A stable sort keeps ties in their existing relative order, and their existing order is alphabetical, so each team comes out alphabetized. The last key sorted becomes the primary key, and each earlier sort becomes a tie-breaker for the later ones.

  It works because of **stability**, which Apple documents for `sort()` and `sorted(by:)`: "The sorting algorithm is guaranteed to be stable." With an unstable sort, teams would still be in order, but within each team the members would come out in whatever order the algorithm happened to leave them, and the "Name" tap would look like it did nothing.

  ```swift
  struct Member {
      let name: String
      let team: String
  }

  var rows = [
      Member(name: "Sofía", team: "Mobile"),
      Member(name: "Ana", team: "Web"),
      Member(name: "Luis", team: "Mobile"),
      Member(name: "Diego", team: "Web"),
      Member(name: "Bea", team: "Mobile"),
  ]
  rows.sort { $0.name < $1.name }
  rows.sort { $0.team < $1.team }
  print(rows.map { "\($0.team) \($0.name)" })
  ```

  ```output
  ["Mobile Bea", "Mobile Luis", "Mobile Sofía", "Web Ana", "Web Diego"]
  ```
````

## Summary

- A **comparison sort** only asks "should a come before b?" and needs about n log₂ n comparisons in the worst case. A **stable** sort keeps ties in their original order. An **in-place** sort rearranges the original storage.
- **Insertion sort** grows a sorted prefix by shifting bigger elements right. O(n²) worst and average, O(n) on sorted input, cheap on nearly sorted input, stable with `>` in the shift condition.
- Apple documents `sort()`, `sort(by:)`, `sorted()` and `sorted(by:)` as **stable** and **O(n log n)**. It doesn't name the algorithm or state its memory use.
- The predicate must be a **strict weak ordering**: irreflexive, transitive, and with transitive ties. `<=` breaks it; in a Swift 6.3 run, ties came out reversed. The docs don't say what happens, so treat the result as unspecified.
- Multiple keys: tuples of up to six `Comparable` elements compare left to right; swap sides for a descending key; map `Bool` to 0/1. Chained stable sorts, least important key first, give the same order.
