---
id: m15-l05
title: Space complexity and the cost of Swift collections
description: You measure the extra memory an algorithm needs, including the call stack of a recursive function, see when copy-on-write actually copies, read the documented costs of Array, Set and Dictionary operations in Apple's own words, learn what "amortized" and "on average" really promise, and turn an O(n²) loop over an array into an O(n) one with a Set.
module: m15
order: 5
level: beginner
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m15-l04]
objectives:
  - Give the extra space of a function in Big O, separately from the space taken by its input and output.
  - Measure the depth of a recursive function and explain why it counts as space.
  - Explain when copy-on-write copies an array, and what that costs.
  - Quote the documented complexity of common Array, Set and Dictionary operations.
  - Explain what "O(1) on average" means for append and for hash-based lookups, and when it doesn't hold.
  - Replace array membership checks inside a loop with a Set, and state the new time and space.
terms:
  - term: Space complexity
    definition: How the memory an algorithm needs grows with n, written in Big O like time.
  - term: Extra space (auxiliary space)
    definition: The memory an algorithm uses beyond its input. When people say "O(1) space" they usually mean extra space, and they say separately whether the output counts.
  - term: Call stack depth
    definition: The largest number of frames on the call stack at once. A recursive function that goes n calls deep uses O(n) space even if it allocates nothing else.
  - term: Copy-on-write
    definition: Arrays, sets and dictionaries share storage when copied, and copy it only when one of the copies is changed. The first change pays O(n) for the copy.
  - term: Amortized cost
    definition: The average cost per operation over a long sequence of operations. Array's append is O(1) on average over many calls, even though a single append that has to grow the storage is O(n).
  - term: Expected (average) O(1)
    definition: The usual cost of a hash table operation when the hash values spread out well. It isn't a guarantee. If many values collide, lookups degrade toward O(n).
mastery:
  - State the extra space of a function that uses a few variables, builds an array or set of size n, or recurses n levels deep.
  - Find the documented complexity of an Array, Set or Dictionary method on its documentation page.
  - Explain why append is O(1) "on average" and why a single append can be O(n).
  - Rewrite a loop that calls contains on an array to use a Set, and give the time and space before and after.
resources: [swift-array, swift-set, swift-dictionary, swift-book-collection-types]
cards:
  - id: m15-l05-c1
    front: What's the extra space of a recursive function that goes n calls deep but creates no arrays?
    back: O(n). Each call keeps a frame on the call stack until it returns, so n frames exist at once at the deepest point.
  - id: m15-l05-c2
    front: What does Apple's documentation say about the cost of Array's append(_:)?
    back: "\"O(1) on average, over many calls to append(_:) on the same array.\" A single append that has to reallocate, or whose storage is shared with a copy, is O(n)."
  - id: m15-l05-c3
    front: When does copy-on-write actually copy an array?
    back: On the first change to an array whose storage is shared with another copy. Assigning or passing the array doesn't copy; the first mutation after that does, in O(n).
  - id: m15-l05-c4
    front: Why say "O(1) on average" for Set and Dictionary lookups?
    back: Hash tables are fast when hash values spread out. If many values land in the same place, a lookup has to compare against all of them, up to O(n). Constant time is expected, not guaranteed.
  - id: m15-l05-c5
    front: A loop calls array.contains(x) for each of n elements. How do you make it O(n)?
    back: Keep the values you need to check in a Set and call set.contains(x) or set.insert(x). That's O(n) time on average in exchange for O(n) extra space.
---

## The idea in one sentence

Memory is a cost too, measured in Big O the same way as time, and every collection operation you call has a cost that Apple documents and that you can look up instead of guessing.

## Space complexity

**Space complexity** is how the memory an algorithm needs grows with n. You almost always mean **extra space**: what the algorithm allocates on top of its input, which is there either way.

```swift
func total(_ values: [Int]) -> Int {
    var sum = 0
    for value in values {
        sum += value
    }
    return sum
}

func doubled(_ values: [Int]) -> [Int] {
    var result: [Int] = []
    for value in values {
        result.append(value * 2)
    }
    return result
}

func hasRepeat(_ values: [Int]) -> Bool {
    var seen = Set<Int>()
    for value in values {
        if !seen.insert(value).inserted {
            return true
        }
    }
    return false
}

print(total([3, 1, 4]), doubled([3, 1, 4]), hasRepeat([3, 1, 4, 1]))
```

```output
8 [6, 2, 8] true
```

- `total` uses one variable, whatever n is: **O(1)** extra space.
- `doubled` builds an array of n elements: **O(n)**. That array is the output, though. When the output is the point of the function, say it: "O(n) for the result, O(1) besides it".
- `hasRepeat` builds a set that can grow to n elements: **O(n)** extra space, spent only to answer yes or no. That's the price of its O(n) running time. Lesson 6 is about prices like that.

A 2D grid of n × n cells is O(n²) space. Space rarely grows faster than time, because filling memory takes time too: an algorithm that allocates O(n²) cells needs at least O(n²) steps to fill them.

## The call stack is space

Module 6 showed that every call gets a frame on the call stack, and the frame stays there until the call returns. A recursive function that goes n levels deep has n frames alive at the same time, so it uses **O(n) space** even if it never creates an array. Measure the depth by passing it down and keeping the deepest value seen:

```swift
func sumUpTo(_ n: Int, depth: Int, deepest: inout Int) -> Int {
    deepest = max(deepest, depth)
    if n <= 0 {
        return 0
    }
    return n + sumUpTo(n - 1, depth: depth + 1, deepest: &deepest)
}

for n in [10, 1_000] {
    var deepest = 0
    let sum = sumUpTo(n, depth: 1, deepest: &deepest)
    print("sum up to \(n) = \(sum), deepest stack: \(deepest) frames")
}
```

```output
sum up to 10 = 55, deepest stack: 11 frames
sum up to 1000 = 500500, deepest stack: 1001 frames
```

n + 1 frames (n down to 0): O(n) space. The loop version of the same sum uses one frame and one variable: O(1). This is also why deep recursion can crash with a stack overflow (Module 6): the stack is a limited amount of memory, and O(n) frames for a large n runs out of it.

Depth is not the same as the number of calls. Naive `fib(30)` makes 2.7 million calls, but at any moment only one path from the top of the tree to a leaf is on the stack, at most 30 frames: exponential time, **O(n)** space. A recursive binary search halves the range on each call, so its depth is about log₂ n: **O(log n)** space, against O(1) for the loop version from lesson 3.

## Copy-on-write, in one paragraph

Arrays, sets and dictionaries are values, so `var copy = original` behaves like a copy (Module 7). Apple's `Array` documentation describes what actually happens: "Multiple copies of an array share the same storage until you modify one of the copies." The copy happens on the first change: "if an array is sharing storage with other copies, the first mutating operation on that array incurs the cost of copying the array." So assigning an array or passing it to a function is O(1), and the first mutation of a shared array is O(n), in time and in space. After that, the mutated array owns its storage, and further changes are done in place. This is why the `append` and subscript documentation mention shared storage: writing to `array[i]` is O(1), "unless the array's storage is shared with another array", in which case it's O(n).

## The documented costs

Each method page in Apple's documentation has a **Complexity** line when the cost is specified. These are the ones you'll use most, quoted as they appear (checked in November 2026; n is the length of the collection unless the quote says otherwise):

### Array

| Operation | Apple's documentation says |
| --- | --- |
| `array[i]` (read) | "Reading an element from an array is O(1)." |
| `array[i] = x` (write) | "Writing is O(1) unless the array's storage is shared with another array or uses a bridged `NSArray` instance as its storage, in which case writing is O(n)" |
| `isEmpty` | "O(1)" |
| `count` | "O(1) if the collection conforms to `RandomAccessCollection`" (Array does: "An ordered, random-access collection") |
| `append(_:)` | "O(1) on average, over many calls to `append(_:)` on the same array." |
| `insert(_:at:)` | "O(n), where n is the length of the array. If `i == endIndex`, this method is equivalent to `append(_:)`." |
| `remove(at:)` | "O(n), where n is the length of the array." |
| `removeFirst()` | "O(n), where n is the length of the collection." |
| `removeLast()`, `popLast()` | "O(1)" |
| `contains(_:)` | "O(n), where n is the length of the sequence." |
| `firstIndex(of:)` | "O(n), where n is the length of the collection." |
| `min()`, `max()` | "O(n), where n is the length of the sequence." |
| `sorted()`, `sort()` | "O(n log n), where n is the length of the sequence." (`sort()` says "collection") |

### Set, Dictionary and String

| Operation | Apple's documentation says |
| --- | --- |
| `set.contains(_:)` | "O(1)" |
| `set.insert(_:)`, `set.remove(_:)` | No complexity line on their pages. |
| `set.count`, `dictionary.count` | "O(1)." |
| `Dictionary` overview | "A dictionary is a type of hash table, providing fast access to the entries it contains." |
| `dictionary[key]` (read or write) | No complexity line on its page. |
| `dictionary.removeValue(forKey:)` | "O(n), where n is the number of key-value pairs in the dictionary." |
| `string.count` | "O(n), where n is the length of the string." |

Two things in these tables need explaining: the "on average" in `append`, and the hash-based operations, where the docs say less than you might expect.

### What "on average" means for append

An array keeps its elements in one block of memory with room to spare, its **capacity**. Appending when there's room is O(1). When the block is full, the array allocates a bigger one and copies every element across: that append is O(n). Apple's `Array` overview explains why this averages out: "The new storage is a multiple of the old storage's size. This exponential growth strategy means that appending an element happens in constant time, averaging the performance of many append operations."

Here's a model of that strategy, counting how many elements get copied. It assumes the capacity starts at 1 and doubles, which is a simplification: Apple documents only that it grows by "a multiple", and the real starting size and factor are implementation details.

```swift
var capacity = 1
var count = 0
var copied = 0
for _ in 1...1_024 {
    if count == capacity {
        copied += count
        capacity *= 2
    }
    count += 1
}
print("\(count) appends, \(copied) elements copied, final capacity \(capacity)")
```

```output
1024 appends, 1023 elements copied, final capacity 1024
```

The copies are 1 + 2 + 4 + … + 512 = 1,023: fewer copies than appends. Each reallocation is expensive, but they get rarer as the array grows, so the total over n appends is O(n) and the cost **per append, averaged over many**, is O(1). That's what **amortized** means. It's a statement about a sequence of appends, not about each one: a single append can still be O(n), which matters in code where one slow step is noticeable, like a frame of an animation.

If you know how many elements you'll add, `reserveCapacity(_:)` allocates the space once and skips the intermediate reallocations. It doesn't change the Big O of the whole loop.

### What "O(1)" means for Set and Dictionary

`Set` and `Dictionary` are hash tables (Module 7). To find a value, they compute its hash, which tells them where to look, and then compare with `==` whatever is stored there. When hashes spread out well, there's usually zero or one value to compare, whatever n is. That's why `set.contains` is fast.

The catch is "spread out well". If many values produce the same hash, they pile up in the same area, and a lookup has to compare against every one of them. To see it, here's a type with a deliberately terrible hash: every badge hashes the same way. The `==` counts how often it's called. (`nonisolated(unsafe)` lets this demo keep a counter in a static variable, which Swift 6 normally forbids for safety; Module 29 explains why. Don't copy it into real code.)

```swift
struct Badge: Hashable {
    let id: Int
    nonisolated(unsafe) static var comparisons = 0

    static func == (left: Badge, right: Badge) -> Bool {
        comparisons += 1
        return left.id == right.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(0)
    }
}

var badges = Set<Badge>()
for id in 0..<1_000 {
    badges.insert(Badge(id: id))
}
Badge.comparisons = 0
print(badges.contains(Badge(id: 5_000)))
print("comparisons: \(Badge.comparisons)")
```

```output
false
comparisons: 1000
```

One `contains` on a set of 1,000 badges compared against all 1,000: a linear search with extra steps. With a real hash (`hasher.combine(id)`, which is what Swift synthesizes if you leave `hash(into:)` out), 1,000 lookups of missing badges averaged about 1.4 comparisons each when this lesson was tested, and the unluckiest single lookup took around 15 to 20. The exact numbers change from run to run, because Swift seeds its hash function randomly for each process, so the block above doesn't print them. That spread is exactly what "on average" means.

So be precise about what you claim:

- Apple's `Set.contains(_:)` page lists **"O(1)"**, and the `Dictionary` overview promises "fast access". That assumes hash values that spread out, which Swift's standard types and synthesized `Hashable` conformances give you.
- For hash tables in general, lookup, insertion and removal are **O(1) on average (expected)** and **O(n) in the worst case**. That's what people mean by "O(1)" for a `Set` or `Dictionary`, and in an interview you say "on average". One of the Contains Duplicate challenge's follow-up questions asks exactly this.
- `Dictionary.removeValue(forKey:)` is listed as O(n), without saying whether that's an average or a worst case. It's consistent with the general picture: fast on average, linear in the worst case.

## Array contains in a loop: O(n²). Set: O(n)

Lesson 4 showed that removing duplicates with `result.contains` inside a loop is O(n²), because `contains` on an array is a linear search. Keep a `Set` of the values seen so far next to the result, and each check becomes a hash lookup:

```swift
func removingDuplicates(_ values: [Int]) -> [Int] {
    var seen = Set<Int>()
    var result: [Int] = []
    for value in values where seen.insert(value).inserted {
        result.append(value)
    }
    return result
}

print(removingDuplicates([3, 1, 3, 2, 1]))
print(removingDuplicates(Array(0..<2_000)).count)
```

```output
[3, 1, 2]
2000
```

For 2,000 unique values, the array version compared 1,999,000 times. This one does 2,000 `insert` calls, each O(1) on average: **O(n) time on average**, and **O(n) extra space** for the set. `insert` both checks and adds, and its `inserted` result says whether the value was new (Module 7). The `where` clause keeps the loop body for new values only.

The same idea solves [Contains Duplicate](#/challenge/contains-duplicate). Try it there, including the follow-up question about why "on average" belongs in the answer.

## A practical example: is this username taken, again

Lesson 1 checked usernames against an array: 50,000 comparisons for every new name. Build a `Set` once and each check is a hash lookup:

```swift
let existing = (1...50_000).map { number in "user\(number)" }
let taken = Set(existing)
for name in ["user7", "user50000", "christian"] {
    print("\(name): taken \(taken.contains(name))")
}
```

```output
user7: taken true
user50000: taken true
christian: taken false
```

The costs, with n = 50,000 names and k checks:

| | Array | Set |
| --- | --- | --- |
| Build | already there | O(n) once: n inserts |
| Each check | O(n), worst case | O(1) on average |
| k checks | O(k · n) | O(n + k) on average |
| Extra space | none | O(n) for the set |

Building the set costs as much as one linear search, so for a single check it's not worth it. For a sign-up screen that checks every few keystrokes, it pays for itself almost immediately. The trade is memory: the set holds its own copy of every name.

## Common mistakes

> [!error] "This function is O(1) space" when it recurses n levels deep
> Each frame lives on the call stack until it returns. Count the deepest point: n frames is O(n) space.

> [!error] "Every append is O(1)"
> Apple's documentation says "O(1) on average, over many calls". A single append can reallocate and copy everything, O(n). The distinction matters when one slow operation is a problem, not just the total.

> [!error] "Set lookups are O(1), guaranteed"
> They're O(1) on average, when hashes spread out. A poor hash function can make every lookup compare against every element. Say "O(1) on average" in interviews.

> [!error] Forgetting the copy when you change a shared array
> `var working = original` is free; the first `working.append(…)` copies all of `original`'s elements, O(n). Inside a loop that copies and then modifies a big array on every pass, that's O(n) per pass.

> [!error] Using removeFirst() or insert(_:at: 0) on a big array in a loop
> Both are documented as O(n). In a loop of n passes, that's O(n²). Use an index, `popLast()`, or a different structure (Module 17).

## Exercises

````exercise
id: m15-l05-e1
type: comprehension
prompt: |
  What's the extra space of this function, where n is `values.count`?

  ```swift
  func hasNegativeAndPositivePair(_ values: [Int]) -> Bool {
      let set = Set(values)
      for value in values where value > 0 && set.contains(-value) {
          return true
      }
      return false
  }
  ```
choices:
  - text: O(1), because it only returns a Bool
    correct: false
    why: The return type doesn't decide the space. The set holds up to n values while the function runs.
  - text: O(n), for the set
    correct: true
    why: Set(values) stores every distinct value, up to n of them.
  - text: O(n²), because it loops and calls contains
    correct: false
    why: That's a time argument, and a wrong one too. set.contains is O(1) on average, so time is O(n) on average.
  - text: O(log n)
    correct: false
    why: Nothing here halves. The set grows with the number of distinct values.
solution: |
  **O(n).** The set can hold every value of the input. Time is O(n) on average: n inserts to build the set and up to n lookups, each O(1) on average. The answer to "is there a pair x and −x?" costs O(n) memory, which is the typical trade with sets.
````

````exercise
id: m15-l05-e2
type: prediction
prompt: Predict the exact output. Each call adds one frame to the call stack; the function returns how deep it went.
code: |
  func depth(of n: Int) -> Int {
      if n <= 1 {
          return 1
      }
      return 1 + depth(of: n / 2)
  }

  print(depth(of: 1), depth(of: 8), depth(of: 1_000), depth(of: 1_000_000))
output: |
  1 4 10 20
hints:
  - The depth is the number of halvings plus one.
  - 1,000,000 can be halved 19 times before reaching 1.
solution: |
  ```output
  1 4 10 20
  ```

  - `depth(of: 1)`: base case right away, 1 frame.
  - 8 → 4 → 2 → 1: four frames.
  - 1,000 halves 9 times (2⁹ = 512 ≤ 1,000 < 1,024), so 10 frames.
  - 1,000,000 halves 19 times, so 20 frames.

  This is the stack of a recursive binary search: **O(log n)** space. Even for a billion elements it would be about 30 frames, no risk of a stack overflow. A recursion that shrinks n by 1 each call would need a million frames for the last input.
````

````exercise
id: m15-l05-e3
type: fill-in
prompt: Fill in the documented complexity of each operation, where n is the number of elements. Use the forms `O(1)`, `O(n)` or `O(n log n)`.
code: |
  numbers.insert(0, at: 0)        // [[1]]
  numbers.removeLast()            // [[2]]
  numbers.sorted()                // [[3]]
  numbers.contains(42)            // [[4]]
  uniqueNumbers.contains(42)      // [[5]] (uniqueNumbers is a Set)
blanks:
  - id: "1"
    answers: ["O(n)"]
  - id: "2"
    answers: ["O(1)"]
  - id: "3"
    answers: ["O(n log n)", "O(nlogn)", "O(n log(n))"]
  - id: "4"
    answers: ["O(n)"]
  - id: "5"
    answers: ["O(1)"]
solution: |
  1. **O(n)**: `insert(_:at:)` is "O(n), where n is the length of the array". Inserting at the front moves every element.
  2. **O(1)**: `removeLast()` is listed as O(1). Nothing moves.
  3. **O(n log n)**: `sorted()`.
  4. **O(n)**: `contains(_:)` on an array is a linear search.
  5. **O(1)**: `Set.contains(_:)` is listed as O(1). In an interview, add "on average": it's a hash table.

  ```swift
  var numbers = [5, 3, 42, 8]
  let uniqueNumbers: Set = [5, 3, 42, 8]
  numbers.insert(0, at: 0)
  numbers.removeLast()
  print(numbers, numbers.sorted(), numbers.contains(42), uniqueNumbers.contains(42))
  ```

  ```output
  [0, 5, 3, 42] [0, 3, 5, 42] true true
  ```
````

````exercise
id: m15-l05-e4
type: find-errors
prompt: |
  A teammate wrote this complexity comment on a function that processes n tasks. Which parts of the comment are wrong?
code: |
  // Complexity: O(n) time, O(1) space.
  // - removeFirst() is O(1), like removeLast().
  // - The Set lookup is O(1) guaranteed.
  // - finished is just the output, so it's free.
  func process(_ tasks: [String], skipping blocked: Set<String>) -> [String] {
      var queue = tasks
      var finished: [String] = []
      while !queue.isEmpty {
          let task = queue.removeFirst()
          if blocked.contains(task) {
              continue
          }
          finished.append(task)
      }
      return finished
  }
choices:
  - text: "removeFirst() is documented as O(n), so the loop is O(n²) in total."
    correct: true
    why: "Every removeFirst() shifts the remaining elements. n removals cost about n²/2 moves."
  - text: "Set lookups are O(1) on average, not guaranteed."
    correct: true
    why: "Hash tables degrade when many values collide. The right wording is \"O(1) on average\"."
  - text: "var queue = tasks copies the array and the first removeFirst() pays for that copy, so O(1) space is wrong."
    correct: true
    why: "queue shares tasks's storage until its first mutation, which copies it: O(n) extra space, besides the output."
  - text: "finished.append(task) is O(n) each time, which also makes it O(n²)."
    correct: false
    why: "Append is O(1) on average over many calls on the same array, so n appends are O(n) in total."
rubric:
  - I identified removeFirst() as the O(n²) cause.
  - I corrected "guaranteed" to "on average".
  - I noticed the copy made by copy-on-write and its O(n) space.
  - I proposed a fix that walks the array instead of removing from the front.
solution: |
  Three of the four claims are wrong. `removeFirst()` is O(n) according to its documentation, which makes the loop **O(n²)**. The set lookup is O(1) **on average**. And `queue` is a mutable copy of `tasks`: the first `removeFirst()` triggers copy-on-write, so the function uses **O(n)** extra space before you count the output. `append` is fine: O(1) on average over many calls.

  The fix needs no queue at all:

  ```swift
  func process(_ tasks: [String], skipping blocked: Set<String>) -> [String] {
      var finished: [String] = []
      for task in tasks where !blocked.contains(task) {
          finished.append(task)
      }
      return finished
  }

  print(process(["build", "test", "deploy", "lint"], skipping: ["deploy"]))
  ```

  ```output
  ["build", "test", "lint"]
  ```

  O(n) time on average, and O(1) extra space besides the O(n) result. `tasks.filter { !blocked.contains($0) }` does the same in one line.
````

````exercise
id: m15-l05-e5
type: solve
prompt: |
  Write `func common(_ a: [String], _ b: [String]) -> [String]` that returns the values of `a` that also appear in `b`, in `a`'s order, each at most once. It must run in O(n + m) time on average, where n is `a.count` and m is `b.count`. State its extra space.

  ```output
  ["kiwi", "apple"]
  []
  ["fig"]
  ```

  Inputs: `(["kiwi", "pear", "apple", "kiwi"], ["apple", "kiwi", "plum"])`, `(["pear"], [])`, `(["fig", "fig"], ["fig"])`.
starter: |
  func common(_ a: [String], _ b: [String]) -> [String] {
      var result: [String] = []
      // Your code
      return result
  }
hints:
  - "Build Set(b) once, before the loop, so each lookup is O(1) on average."
  - "To keep each value once, track the values you've already added in a second Set."
rubric:
  - The function builds a Set from b once, outside the loop.
  - Each value appears in the result at most once, in a's order.
  - The output matches.
  - I stated O(n + m) time on average and O(m + n) extra space (the two sets), besides the result.
solution: |
  ```swift
  func common(_ a: [String], _ b: [String]) -> [String] {
      let inB = Set(b)
      var added = Set<String>()
      var result: [String] = []
      for value in a where inB.contains(value) && added.insert(value).inserted {
          result.append(value)
      }
      return result
  }

  print(common(["kiwi", "pear", "apple", "kiwi"], ["apple", "kiwi", "plum"]))
  print(common(["pear"], []))
  print(common(["fig", "fig"], ["fig"]))
  ```

  ```output
  ["kiwi", "apple"]
  []
  ["fig"]
  ```

  `Set(b)` costs O(m) once. The loop does n iterations with two hash operations each, O(1) on average: O(n). Total **O(n + m) on average**. Extra space: up to m for `inB` and up to n for `added`, so **O(n + m)**, plus the result. `&&` stops at the first `false`, so `added.insert` only runs for values that are in `b`.

  The nested-loop version (lesson 4, exercise 5) was O(n · m) with O(1) extra space. Same answer, different trade.
````

````exercise
id: m15-l05-e6
type: explain
prompt: |
  In code review, someone asks: "Apple says append is O(1). Then why did one append in my animation loop take much longer than the others?" Explain what the documentation actually says, why a single append can be slow, and what they can do about it.
code: |
  var positions = Array(repeating: 0.0, count: 10_000)
  let history = positions
  for frame in 0..<600 {
      positions.append(Double(frame) * 0.5)
  }
  print(history.count, positions.count)
rubric:
  - I quoted or paraphrased "O(1) on average, over many calls to append(_:) on the same array".
  - I explained reallocation and copying when the capacity runs out, and that it's O(n) for that one append.
  - I mentioned shared storage (copy-on-write) as the other case that makes an append O(n).
  - I suggested reserveCapacity(_:) when the final size is known, or creating the array once outside the loop.
solution: |
  The documentation doesn't say every append is O(1). It says "O(1) on average, over many calls to `append(_:)` on the same array", and the method's discussion adds: "When an array needs to reallocate storage before appending or its storage is shared with another copy, appending is O(n), where n is the length of the array."

  So two things can make one append slow:
  - **The array ran out of capacity.** It allocates a larger block (a multiple of the old size) and copies every element: O(n) for that append. Because the capacity grows by a multiple, these get rarer and rarer, and the average stays O(1). The average doesn't help an animation that needs every frame to be fast.
  - **The storage was shared.** In the code above, `history` holds a copy of `positions`, so the first append has to make `positions` a private copy of all 10,000 elements before it can add one (copy-on-write): O(n).

  What to do: if the final size is known, call `reserveCapacity(_:)` before the loop so the space is allocated once. Make sure no other variable holds a copy of the array while you append to it. And if the array is rebuilt every frame, consider building it once and reusing it. Then measure with Instruments to confirm the fix; Big O tells you where to look, not how many milliseconds you saved.
````

## Summary

- Space complexity is usually **extra space**: what the algorithm allocates beyond its input. Say separately whether the output counts.
- Recursion uses the call stack: depth n is O(n) space, even with no arrays. Halving recursion is O(log n) deep.
- Copy-on-write: assigning or passing a collection is cheap; the **first mutation** of shared storage copies it, O(n).
- Look up costs on Apple's method pages. Array: subscript O(1), `append` "O(1) on average, over many calls", `insert(_:at:)`, `remove(at:)`, `removeFirst()`, `contains` and `firstIndex(of:)` O(n), `removeLast()` O(1), `sorted()` O(n log n). `String.count` is O(n).
- `Set.contains` is listed as O(1), and dictionaries are "a type of hash table, providing fast access". For hash tables, say **O(1) on average**: colliding hashes make lookups linear.
- An array `contains` inside a loop is O(n²). A `Set` makes it O(n) on average, for O(n) extra space.
