---
id: m07-l04
title: "Sets: uniqueness and fast membership"
description: You use sets to keep values unique and to check membership quickly, combine them with union, intersection and subtracting, remove duplicates from an array, and choose between Array, Set and Dictionary for a given job.
module: m07
order: 4
level: beginner
minutes: 45
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m07-l03]
objectives:
  - Create sets from literals and arrays, and add, remove and check elements.
  - Combine sets with union, intersection and subtracting.
  - Remove duplicates from an array, with and without keeping the original order.
  - Explain in plain words why contains is fast on a Set and slow on an Array.
  - Choose between Array, Set and Dictionary from a problem's needs.
terms:
  - term: Set
    definition: An unordered collection of unique values. Its type is written Set<Element>, like Set<String>.
  - term: Membership test
    definition: Asking whether a value is in a collection, with contains.
  - term: Hashing
    definition: Turning a value into a number (its hash) that tells a Set or a Dictionary where to store and find it, so it can go straight there instead of searching.
  - term: Union, intersection, difference
    definition: "Set operations: everything in either set, only what's in both, and what's in the first but not the second."
mastery:
  - Declare a set from a literal and explain why the annotation is needed.
  - Predict the contents of a set after inserting duplicates.
  - Compute the union, intersection and difference of two sets and print the result in a stable order.
  - Remove duplicates from an array while keeping the first occurrence of each value in order.
  - Justify choosing an Array, a Set or a Dictionary for a given task.
resources: [swift-set, swift-book-collection-types, swift-book-control-flow]
cards:
  - id: m07-l04-c1
    front: What are the two defining properties of a Set?
    back: Its elements are unique, and it has no order. Inserting a value that's already there does nothing.
  - id: m07-l04-c2
    front: Why is contains fast on a Set and slow on an Array?
    back: An Array checks elements one by one, up to N steps. A Set hashes the value to compute where it would be stored and looks only there, which takes about the same time however big the set is.
  - id: m07-l04-c3
    front: What do union, intersection and subtracting return?
    back: "a.union(b): everything in either. a.intersection(b): only what's in both. a.subtracting(b): what's in a but not in b. All three return a new Set."
  - id: m07-l04-c4
    front: Why does Array(Set(values)) not keep the original order?
    back: A Set has no order. Converting back to an array gives the elements in the set's internal order. To keep the order, loop over the array and use a set only to remember what you've seen.
---

## The idea in one sentence

A set is a bag of **unique** values with no order, built so that "is this value in here?" is answered almost instantly.

## Creating a set

**Plain definition:** a set is a collection where each value appears at most once and position doesn't exist.

**Precise definition:** `Set<Element>` is an unordered collection of distinct elements of a `Hashable` type. It has no indexes, so there's no `set[0]`.

```swift
let colors: Set<String> = ["red", "green", "red", "blue"]
let primes: Set = [2, 3, 5, 7, 5]
var tags = Set<String>()
print(colors.count)
print(primes.count)
print(tags.isEmpty)
```

```output
3
4
true
```

1. The literal has the same square brackets as an array literal. The **annotation** `Set<String>` is what makes it a set; without it, Swift would build an array. The duplicate `"red"` is dropped, so there are 3 elements.
2. `Set` alone, without the element type, is enough: Swift infers `Set<Int>` from the elements. The second 5 is dropped: 4 elements.
3. An empty set, created by calling the type, like `[Int]()`.
4. `isEmpty` and `count` work the same as on arrays.

Like a dictionary, a set has **no stable order**. `print(colors)` would show the elements in an order that can change from run to run, so this lesson only prints sets after sorting them. `sorted()` returns an array:

```swift
let colors: Set<String> = ["red", "green", "red", "blue"]
print(colors.sorted())
```

```output
["blue", "green", "red"]
```

## Inserting, removing and checking

```swift
var visited: Set<String> = ["Lima"]
visited.insert("Quito")
visited.insert("Lima")
print(visited.count)
print(visited.contains("Quito"))
visited.remove("Quito")
print(visited.contains("Quito"))
print(visited.sorted())
```

```output
2
true
false
["Lima"]
```

1. A set with one city.
2. `insert` adds `"Quito"`.
3. Inserting `"Lima"` again does nothing: it's already there. No error, no duplicate.
4. Two elements.
5. `contains` answers membership, the operation sets are built for.
6. `remove` takes the element out. It also returns it as an optional, which you can ignore.
7. Not there anymore.

### Did the insert do anything?

`insert` tells you whether the value was new. It returns a tuple (Module 6), and its `inserted` part is a `Bool`: `true` if the value was added, `false` if it was already there. You can ignore it, as above, or use it:

```swift
var seen: Set<Int> = []
for number in [4, 7, 4, 9, 7] {
    if seen.insert(number).inserted {
        print("\(number) is new")
    } else {
        print("\(number) again")
    }
}
```

```output
4 is new
7 is new
4 again
9 is new
7 again
```

`seen.insert(number)` adds the number (if it's new) **and** reports what happened, in one step.

## Why contains is fast

Here's the difference that makes sets worth learning.

`array.contains(x)` is a **linear search**: it compares `x` with the first element, then the second, and so on. On an array of a million elements, a value that isn't there costs a million comparisons.

A set doesn't search. When you insert a value, the set runs it through a **hash function**, which turns the value into a number, its **hash**. That number decides which slot the value goes in. When you later ask `contains(x)`, the set hashes `x` again, gets the same number, and looks in that one slot. It doesn't matter whether the set has ten elements or ten million: it computes one hash and checks one place (occasionally a few, when two values land in the same slot).

An analogy: an array is a pile of papers you flip through one by one. A set is a filing cabinet with a labeled drawer for each first letter, so you open the right drawer straight away. The analogy breaks down in one way: a hash doesn't put similar values near each other, so a set can't answer "what's the next value after 7?" It only knows "is 7 here?"

That's also why a set has no order, and why elements must be **`Hashable`**: the set needs a hash for every element. `Int`, `String`, `Double`, `Bool` and `Character` are all `Hashable`. Dictionaries work the same way, which is why their **keys** must be `Hashable` and why a lookup by key is fast. Module 15 measures these costs precisely.

The [Contains Duplicate](#/challenge/contains-duplicate) challenge is the textbook use: walk the array once, and for each value ask the set "have I seen this?" One pass of N fast checks instead of comparing every pair.

## Combining sets

Sets have the operations you may remember from math class. Each returns a new set, so sort it before printing:

```swift
let monday: Set = ["Ana", "Luis", "Marta"]
let tuesday: Set = ["Luis", "Sofía", "Marta", "Diego"]
print(monday.union(tuesday).sorted())
print(monday.intersection(tuesday).sorted())
print(monday.subtracting(tuesday).sorted())
print(tuesday.subtracting(monday).sorted())
```

```output
["Ana", "Diego", "Luis", "Marta", "Sofía"]
["Luis", "Marta"]
["Ana"]
["Diego", "Sofía"]
```

| Operation | Means | Here |
| --- | --- | --- |
| `a.union(b)` | in `a` or `b` (or both) | everyone who came on either day |
| `a.intersection(b)` | in both | who came both days |
| `a.subtracting(b)` | in `a` but not in `b` | who came Monday only |

`subtracting` isn't symmetric: Monday minus Tuesday is Ana; Tuesday minus Monday is Diego and Sofía. There's also `a.isSubset(of: b)`, which asks whether every element of `a` is in `b`.

## Removing duplicates from an array

The quick way: turn the array into a set, which drops the duplicates, and sort it back into an array.

```swift
let emails = ["b@x.com", "a@x.com", "b@x.com", "c@x.com", "a@x.com"]
let unique = Set(emails).sorted()
print(unique)
```

```output
["a@x.com", "b@x.com", "c@x.com"]
```

`Set(emails)` builds a set from any array. That works when sorted order is what you want. But often you need the **original** order, the order the users signed up in, say. `Array(Set(emails))` would scramble it. Use the set only to remember what you've seen, and build the result as an array:

```swift
func removingDuplicates(from values: [String]) -> [String] {
    var seen: Set<String> = []
    var result: [String] = []
    for value in values {
        if !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
    }
    return result
}

let emails = ["b@x.com", "a@x.com", "b@x.com", "c@x.com", "a@x.com"]
print(removingDuplicates(from: emails))
```

```output
["b@x.com", "a@x.com", "c@x.com"]
```

Each value is checked against the set, a fast lookup, and appended only the first time. Order kept, duplicates gone, one pass. You could check `result.contains(value)` instead of keeping a set, and it would give the same answer, but each check would be a linear search through `result`: for big inputs, a lot slower.

## Array, Set or Dictionary?

| Question | Array | Set | Dictionary |
| --- | --- | --- | --- |
| Keeps order? | Yes | No | No |
| Allows duplicates? | Yes | No | Keys no, values yes |
| Look up by | position | the value itself | key |
| `contains` / lookup cost | up to N steps | about 1 step | about 1 step (by key) |
| Use it for | sequences, lists, history, anything you'll index | membership, uniqueness, "seen before?" | facts about each key, counts, indexes by name |

Three questions decide it:

1. **Does order matter, or can things repeat?** Array.
2. **Do you only care whether something is present?** Set.
3. **Do you need to store something about each item and find it by name?** Dictionary.

Programs often combine them, as `removingDuplicates` does: an array for the ordered result, a set for the fast "seen?" check.

## Common mistakes

> [!error] Forgetting the annotation
> `let tags = ["a", "b", "a"]` is an **array** with three elements, duplicates included. A set literal needs `Set` in the type: `let tags: Set = ["a", "b", "a"]`.

> [!error] error: no exact matches in call to subscript
> You tried to read a set by position, like `colors[0]`. Sets have no positions. Use `contains` to check membership, or `sorted()` to get an array you can index. Swift 6.3's message doesn't mention order at all, which makes this one confusing the first time:

```swift no-compile no exact matches in call to subscript
let colors: Set = ["red", "green"]
print(colors[0])
```

> [!error] Printing a set and expecting a fixed order
> `print(mySet)` can show its elements in a different order on every run. Print `mySet.sorted()` instead.

> [!error] Using Array(Set(x)) when order matters
> It removes duplicates and destroys the order. Keep the order with a loop and a `seen` set.

````exercise
id: m07-l04-e1
type: comprehension
prompt: A chat app needs to know whether a username is already taken before letting someone register. It has two million users. Which structure should hold the taken names?
choices:
  - text: An array of usernames, checked with contains.
    correct: false
    why: It gives the right answer, but checks up to two million names per registration.
  - text: A Set of usernames, checked with contains.
    correct: true
    why: The question is pure membership, and a Set answers it in about one step.
  - text: A dictionary from usernames to the number 1.
    correct: false
    why: It works, but the values carry no information. A Set says what you mean.
  - text: An array sorted alphabetically, read by index.
    correct: false
    why: An index tells you a position, not whether a name exists. You'd still have to search.
solution: |
  **A Set.** The only question asked is "is this name present?", and the names are unique by nature. A set hashes the name and checks one place, however many users there are. An array would work but checks names one by one. A dictionary would also be fast, but storing a meaningless value for each key is a sign you wanted a set. (If you later need each user's signup date, that's when a dictionary keyed by username makes sense.)
````

````exercise
id: m07-l04-e2
type: prediction
prompt: Predict the exact output, line by line.
code: |
  var letters: Set<Character> = ["a", "b"]
  letters.insert("c")
  letters.insert("a")
  print(letters.count)
  let other: Set<Character> = ["b", "c", "d"]
  print(letters.intersection(other).sorted())
  print(letters.subtracting(other).sorted())
  print(other.union(letters).count)
  print(letters.contains("d"), other.contains("d"))
output: |
  3
  ["b", "c"]
  ["a"]
  4
  false true
hints:
  - Inserting "a" a second time does nothing.
  - "union counts each letter once: a, b, c, d."
solution: |
  ```output
  3
  ["b", "c"]
  ["a"]
  4
  false true
  ```

  After the inserts, `letters` is {a, b, c}: the second "a" is ignored, so count is 3. With other = {b, c, d}: both have b and c; only `letters` has a; together they have a, b, c and d, four letters. Only `other` contains d. Each set result is sorted before printing, so the output is stable. `sorted()` on characters returns `[Character]`, which prints with double quotes like strings.
````

````exercise
id: m07-l04-e3
type: fill-in
prompt: |
  Complete the program so it prints the students enrolled in both courses and those in math only:

  ```output
  ["Ana", "Luis"]
  ["Diego"]
  ```
code: |
  let math: [[1]] = ["Ana", "Diego", "Luis"]
  let art: Set = ["Luis", "Marta", "Ana"]
  print(math.[[2]](art).sorted())
  print(math.[[3]](art).sorted())
blanks:
  - id: "1"
    answers: ["Set", "Set<String>"]
  - id: "2"
    answers: ["intersection"]
  - id: "3"
    answers: ["subtracting"]
solution: |
  ```swift
  let math: Set = ["Ana", "Diego", "Luis"]
  let art: Set = ["Luis", "Marta", "Ana"]
  print(math.intersection(art).sorted())
  print(math.subtracting(art).sorted())
  ```

  ```output
  ["Ana", "Luis"]
  ["Diego"]
  ```

  `math` needs a set annotation, `Set` or `Set<String>`; without it, it would be an array, and arrays don't have `intersection`. Ana and Luis take both courses; Diego takes only math. Marta is only in art, so she shows up in neither line.
````

````exercise
id: m07-l04-e4
type: solve
prompt: |
  Write `func hasDuplicate(_ values: [Int]) -> Bool` that returns `true` as soon as it finds a value it has already seen, using a `Set`. Then print the results for `[3, 1, 4, 1, 5]`, `[1, 2, 3]` and `[]`:

  ```output
  true
  false
  false
  ```
starter: |
  func hasDuplicate(_ values: [Int]) -> Bool {
      // Your code
      return false
  }
hints:
  - Keep a Set<Int> of the values seen so far.
  - Before inserting a value, check whether the set already contains it. Or use insert(_:).inserted.
rubric:
  - The function makes one pass over the array.
  - It returns as soon as it finds the first repeated value.
  - It returns false for an empty array.
  - I can explain why this is faster than comparing every pair.
solution: |
  ```swift
  func hasDuplicate(_ values: [Int]) -> Bool {
      var seen: Set<Int> = []
      for value in values {
          if seen.contains(value) {
              return true
          }
          seen.insert(value)
      }
      return false
  }

  print(hasDuplicate([3, 1, 4, 1, 5]))
  print(hasDuplicate([1, 2, 3]))
  print(hasDuplicate([]))
  ```

  ```output
  true
  false
  false
  ```

  For `[3, 1, 4, 1, 5]`, the set grows to {3, 1, 4}; when the second 1 arrives, `contains` finds it and the function returns without looking at 5. An empty array skips the loop and returns `false`.

  The naive version compares every pair with two nested loops: for N values, about N × N / 2 comparisons. This version does one fast set check per value, about N steps in total. The trade-off is memory: the set can grow to hold all N values. That's exactly the Contains Duplicate challenge.

  A shorter alternative that always processes the whole array: `return Set(values).count != values.count`. If the set is smaller, something was dropped, so something repeated.
````

````exercise
id: m07-l04-e5
type: design
prompt: |
  A music app stores, for one user: the songs in their current queue (played in order, a song can be queued twice), the songs they've liked (each at most once, checked every time a song plays to show a heart), and how many times they've played each song. Choose an Array, a Set or a Dictionary for each and justify it.
rubric:
  - The queue is an array, because order and repeats matter.
  - The liked songs are a Set, because the question is membership and each song is liked at most once.
  - The play counts are a dictionary from song to Int, updated with the default subscript.
  - Each justification mentions order, uniqueness or lookup.
solution: |
  - **Queue: `[String]`.** Order is the whole point, and the same song can be queued twice. You add with `append` or `insert(_:at:)` and play from the front.
  - **Liked songs: `Set<String>`.** Each song is either liked or not, never twice, and the app asks `liked.contains(song)` every time a song plays. A set answers that in about one step however many songs the user has liked. An array would work but would get slower as the list grows, and could hold the same song twice by mistake.
  - **Play counts: `[String: Int]`.** You need a number **for each** song, found by song. `plays[song, default: 0] += 1` every time one finishes. For a "most played" screen, sort the keys (or the pairs by count) before showing them.

  In a real app, songs would have an ID rather than a title as the key, since two songs can share a title. You'll model that with structs in Module 9.
````

## Summary

- A `Set` holds unique values with no order. Declare it with an annotation: `let s: Set = [1, 2, 3]` or `Set<String>()`.
- `insert`, `remove` and `contains` are the core operations. Inserting a value that's already there does nothing; `insert(_:).inserted` tells you which happened.
- `contains` on a set hashes the value and checks one place, so it stays fast as the set grows. On an array it's a linear search.
- `union`, `intersection` and `subtracting` combine sets. Sort before printing.
- `Set(array)` drops duplicates but not the order problem: to keep the original order, loop and use a `seen` set.
- Order or repeats: Array. Membership: Set. Data about each key: Dictionary.
