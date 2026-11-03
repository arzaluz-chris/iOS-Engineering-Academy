---
id: m18-l02
title: Backtracking
description: You generate every subset, permutation and combination of a collection with one template, choose, explore, unchoose, and see the decision tree it walks. You decide between passing copies of the partial answer and mutating one shared array, learn why recording an array is safe and recording a class isn't, and count how fast these searches grow.
module: m18
order: 2
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m18-l01]
objectives:
  - Write a backtracking function with the choose, explore, unchoose template.
  - Generate all subsets, permutations and size-k combinations of an array.
  - Draw the decision tree a backtracking function explores and relate it to the output order.
  - Choose between passing copies of the partial answer and mutating it in place with append and removeLast or inout.
  - State the number of results and the cost of each generator.
terms:
  - term: Backtracking
    definition: Building candidate answers one choice at a time, recursing after each choice, and undoing the choice when the recursion returns, so the next alternative starts from the same state.
  - term: Decision tree
    definition: The tree of partial answers a backtracking search visits. The root is the empty answer, each edge is one choice, and each path from the root is a sequence of choices.
  - term: Choose, explore, unchoose
    definition: "The three steps inside a backtracking loop: apply a choice to the shared state, recurse, then revert the state to what it was before the choice."
  - term: Subset
    definition: Any selection of elements from a collection, ignoring order, including the empty one and the whole collection. A collection of n distinct elements has 2ⁿ subsets.
  - term: Permutation
    definition: An ordering of all the elements of a collection. n distinct elements have n! permutations.
  - term: Combination
    definition: A selection of exactly k elements, ignoring order. There are n! / (k! (n − k)!) of them, written C(n, k).
mastery:
  - Write subsets, permutations and combinations from the same template without looking.
  - Predict the order in which a backtracking function produces its results.
  - Explain why results.append(current) records a snapshot when current is an array.
  - Say how many results each generator produces for n = 10 and why that limits n.
resources: [swift-book-functions, swift-book-closures, swift-book-structures-classes, swift-array]
cards:
  - id: m18-l02-c1
    front: What are the three steps inside a backtracking loop?
    back: "Choose (apply one option to the shared partial answer), explore (recurse), unchoose (undo the option so the next one starts from the same state). With append, it's append, recurse, removeLast."
  - id: m18-l02-c2
    front: How do subsets and combinations avoid producing [a, b] and [b, a] as different results?
    back: They pass a start index and only choose elements after the last one chosen, so every selection is built in index order exactly once.
  - id: m18-l02-c3
    front: How do permutations differ from subsets in the backtracking loop?
    back: Permutations loop over every element each time and skip the ones already used (a used array of Bool), and they record only when the partial answer has all n elements.
  - id: m18-l02-c4
    front: Why is results.append(current) safe when current is a [Int] you keep mutating?
    back: Arrays are values. Appending stores a copy (copy-on-write makes it lazy), and later appends and removeLasts on current don't affect it. If current were a class instance, every result would be the same object.
  - id: m18-l02-c5
    front: How many subsets, permutations and 3-element combinations does a 10-element array have?
    back: 2¹⁰ = 1,024 subsets, 10! = 3,628,800 permutations, C(10, 3) = 120 combinations. Generating them costs at least that many results times the work to copy each.
---

## The idea in one sentence

Backtracking builds answers one choice at a time: make a choice, explore everything that follows from it, **undo it**, and try the next choice, so that a single shared partial answer walks the whole tree of possibilities.

## The template

Every backtracking function in this module has the same skeleton:

```pseudo
Explore(partial answer):
  If the partial answer is complete then record it
  For each choice still available
    Choose: add the choice to the partial answer
    Explore(partial answer)
    Unchoose: remove the choice from the partial answer
```

The unchoose step is what gives the technique its name. When `Explore` returns, the partial answer is exactly what it was before the choice, so the loop can try the next choice from a clean state. Three questions decide every backtracking problem:

1. What is the **partial answer**? (An array of picks, a board, a string being built.)
2. What are the **choices** at each step, and which ones are still available?
3. When is a partial answer **complete**, or worth recording?

## Subsets

Choices: any element after the last one picked. Every partial answer is a valid subset, so record each one:

```swift
func subsets(of items: [String]) -> [[String]] {
    var results: [[String]] = []
    var current: [String] = []

    func explore(from start: Int) {
        results.append(current)
        for i in start..<items.count {
            current.append(items[i])
            explore(from: i + 1)
            current.removeLast()
        }
    }

    explore(from: 0)
    return results
}

for subset in subsets(of: ["a", "b", "c"]) {
    print(subset)
}
```

```output
[]
["a"]
["a", "b"]
["a", "b", "c"]
["a", "c"]
["b"]
["b", "c"]
["c"]
```

Line by line:

- `explore` is a **nested function**: it can read `items` and change `results` and `current`, which belong to the outer function. That keeps the recursive signature down to the one thing that varies, `start`.
- `results.append(current)` records the subset as it stands. The empty subset is recorded by the very first call.
- `for i in start..<items.count` offers only elements **after** the last one picked. That's what stops `["b", "a"]` from appearing next to `["a", "b"]`: every subset is built in index order, exactly once.
- `current.append(items[i])` is the choice, `explore(from: i + 1)` explores everything that starts with it, and `current.removeLast()` undoes it.
- When `start == items.count`, the range is empty and the call returns after recording. That's the base case, the empty loop again.

The decision tree it walks, with the order each node is recorded:

```text
                    [] 1
          /           |          \
      [a] 2         [b] 6       [c] 8
     /     \          |
 [a,b] 3  [a,c] 5   [b,c] 7
    |
[a,b,c] 4
```

The output order is the order of a depth-first walk of this tree: go as deep as possible, back up one level, take the next branch. 8 nodes, 8 subsets: 2³. Each element is either in a subset or not, so n elements give **2ⁿ subsets**.

## Permutations

A permutation uses every element, in some order. Now the choices at each step are **every element not used yet**, and you only record when all n are placed:

```swift
func permutations(of items: [Int]) -> [[Int]] {
    var results: [[Int]] = []
    var current: [Int] = []
    var used = Array(repeating: false, count: items.count)

    func explore() {
        if current.count == items.count {
            results.append(current)
            return
        }
        for i in items.indices where !used[i] {
            used[i] = true
            current.append(items[i])
            explore()
            current.removeLast()
            used[i] = false
        }
    }

    explore()
    return results
}

let orders = permutations(of: [1, 2, 3])
print(orders.count)
for order in orders {
    print(order)
}
print(permutations(of: [1, 2, 3, 4, 5]).count)
```

```output
6
[1, 2, 3]
[1, 3, 2]
[2, 1, 3]
[2, 3, 1]
[3, 1, 2]
[3, 2, 1]
120
```

The shared state is two things now, `current` and `used`, and both are chosen and unchosen together. Unchoose in the reverse order of choose, so the state unwinds cleanly. There are n choices for the first position, n − 1 for the second, and so on: **n! permutations**.

## Combinations

A combination is a subset of exactly k elements. Take the subsets code, record only at size k, and stop going deeper once you're there:

```swift
func combinations(of items: [String], size k: Int) -> [[String]] {
    var results: [[String]] = []
    var current: [String] = []

    func explore(from start: Int) {
        if current.count == k {
            results.append(current)
            return
        }
        for i in start..<items.count {
            current.append(items[i])
            explore(from: i + 1)
            current.removeLast()
        }
    }

    explore(from: 0)
    return results
}

let pairs = combinations(of: ["a", "b", "c", "d"], size: 2)
print(pairs.count, pairs)
print(combinations(of: ["a", "b", "c", "d", "e"], size: 3).count)
```

```output
6 [["a", "b"], ["a", "c"], ["a", "d"], ["b", "c"], ["b", "d"], ["c", "d"]]
10
```

The `return` after recording is what makes it "exactly k": without it, the search would keep adding elements past k for nothing. C(4, 2) = 6 and C(5, 3) = 10.

## Copying the state or mutating it

The versions above mutate one shared `current` and undo each change. The other style passes a **new array** to each call and never undoes anything:

```swift
func subsetsByCopying(of items: [String]) -> [[String]] {
    var results: [[String]] = []

    func explore(from start: Int, current: [String]) {
        results.append(current)
        for i in start..<items.count {
            explore(from: i + 1, current: current + [items[i]])
        }
    }

    explore(from: 0, current: [])
    return results
}

print(subsetsByCopying(of: ["a", "b", "c"]))
```

```output
[[], ["a"], ["a", "b"], ["a", "b", "c"], ["a", "c"], ["b"], ["b", "c"], ["c"]]
```

Same results, same order. `current + [items[i]]` builds a new array for the call, so each frame has its own partial answer and there's nothing to undo. The trade:

| | Copy per call | Mutate and undo |
| --- | --- | --- |
| Undo step | None; can't forget it | Required; forgetting it is the classic bug |
| Cost per choice | O(length of the partial answer) to build the new array | O(1) amortized for `append` and `removeLast` |
| Best for | Small states, and when you're learning | Big states (a 9×9 board), hot loops |

For a top-level function instead of a nested one, the mutating style passes the state as `inout`, the way Module 15 passed counters:

```swift
func explore(_ items: [Int], from start: Int, current: inout [Int], results: inout [[Int]]) {
    results.append(current)
    for i in start..<items.count {
        current.append(items[i])
        explore(items, from: i + 1, current: &current, results: &results)
        current.removeLast()
    }
}

var current: [Int] = []
var results: [[Int]] = []
explore([1, 2], from: 0, current: &current, results: &results)
print(results)
print(current)
```

```output
[[], [1], [1, 2], [2]]
[]
```

`current` ends empty: every choice was undone. That's a cheap check that your unchoose steps match your choose steps.

### Why recording an array is safe

`results.append(current)` stores the array **as it is right now**. Later `append` and `removeLast` calls on `current` don't reach into `results`, because arrays are values (Module 10): appending stores a copy, and copy-on-write only makes that copy when `current` is next modified. If the partial answer is a **class**, the same line stores a reference to one shared object:

```swift
final class Path {
    var steps: [String] = []
}

func subsetsSharingAnObject(_ items: [String]) -> [[String]] {
    var results: [Path] = []
    let current = Path()

    func explore(from start: Int) {
        results.append(current)
        for i in start..<items.count {
            current.steps.append(items[i])
            explore(from: i + 1)
            current.steps.removeLast()
        }
    }

    explore(from: 0)
    return results.map { $0.steps }
}

print(subsetsSharingAnObject(["a", "b"]))
```

```output
[[], [], [], []]
```

Four results, all the same object, and by the end that object is empty because every choice was undone. If you use a class for the state, record a copy of its contents (`results.append(current.steps)`), not the object. Exercise 6 asks you to explain this.

## How fast these grow

Backtracking that generates **every** answer can't be faster than the number of answers:

| n | Subsets 2ⁿ | Permutations n! | Combinations C(n, 3) |
| --- | --- | --- | --- |
| 5 | 32 | 120 | 10 |
| 10 | 1,024 | 3,628,800 | 120 |
| 15 | 32,768 | 1,307,674,368,000 | 455 |
| 20 | 1,048,576 | about 2.4 × 10¹⁸ | 1,140 |

Recording each result copies it, which costs its length, so subsets are **O(n · 2ⁿ)** and permutations **O(n · n!)**. Subsets are usable up to about 20 elements; permutations up to about 10. The recursion depth is only n (one level per element), so the stack is never the problem here; the number of nodes is. When you only need answers that satisfy a constraint, cutting branches early is the next lesson.

## A practical example: test configurations

An app has accessibility and appearance settings that interact badly in ways nobody predicted: large text plus a narrow layout, reduce motion plus a custom transition. A QA plan can test every combination of a handful of settings, or, when there are too many, every pair:

```swift
func subsets(of items: [String]) -> [[String]] {
    var results: [[String]] = []
    var current: [String] = []

    func explore(from start: Int) {
        results.append(current)
        for i in start..<items.count {
            current.append(items[i])
            explore(from: i + 1)
            current.removeLast()
        }
    }

    explore(from: 0)
    return results
}

func combinations(of items: [String], size k: Int) -> [[String]] {
    var results: [[String]] = []
    var current: [String] = []

    func explore(from start: Int) {
        if current.count == k {
            results.append(current)
            return
        }
        for i in start..<items.count {
            current.append(items[i])
            explore(from: i + 1)
            current.removeLast()
        }
    }

    explore(from: 0)
    return results
}

let settings = ["darkMode", "largeText", "reduceMotion"]
for configuration in subsets(of: settings) {
    let label = configuration.isEmpty ? "defaults" : configuration.joined(separator: " + ")
    print(label)
}

let manySettings = ["darkMode", "largeText", "reduceMotion", "boldText", "increaseContrast", "rightToLeft"]
print("All combinations:", subsets(of: manySettings).count)
print("Every pair:", combinations(of: manySettings, size: 2).count)
```

```output
defaults
darkMode
darkMode + largeText
darkMode + largeText + reduceMotion
darkMode + reduceMotion
largeText
largeText + reduceMotion
reduceMotion
All combinations: 64
Every pair: 15
```

Three settings give 8 configurations, fine to test by hand. Six give 64, and twelve would give 4,096. Every pair of six settings is 15. Pairwise testing is a real QA technique built on the observation that many bugs come from two settings interacting; whether it's enough for a given app is a judgment call, but the counts are what make it attractive.

## Common mistakes

> [!error] Forgetting to unchoose
> Without `current.removeLast()`, every choice stays in `current` forever. The subsets of `["a", "b", "c"]` come out as `[]`, `["a"]`, `["a", "b"]`, `["a", "b", "c"]`, `["a", "b", "c", "c"]`… The results keep growing instead of branching. If the state isn't back to empty after the top-level call, an unchoose is missing.

> [!error] Looping from 0 instead of from start
> In subsets and combinations, `for i in 0..<items.count` offers elements you've already passed, so `["a", "b"]` and `["b", "a"]` both appear, along with `["a", "a"]`. Ordered results need the start index; only permutations loop over everything (and skip what's used).

> [!error] Recording a reference
> A class instance as the partial answer, appended to `results`, means every result is the same object. Record a value: an array, a string, or a copy of the class's contents.

> [!error] Undoing in the wrong order
> With two pieces of state, unchoose the last thing you chose first. In permutations, `current.removeLast()` and then `used[i] = false` is clear; undoing a different index from the one you chose leaves the state wrong in ways that show up three levels later.

## Exercises

````exercise
id: m18-l02-e1
type: comprehension
prompt: |
  You start from the `subsets` function. Which single change makes it return only the subsets with exactly 2 elements, without exploring anything deeper than 2?
choices:
  - text: "At the top of explore: if current.count == 2, append current and return; otherwise don't append."
    correct: true
    why: "That's the combinations function: record at size k, and the return stops the search from going past k."
  - text: "Filter the results afterwards with results.filter { $0.count == 2 }."
    correct: false
    why: "It gives the right answer, but it still generates all 2ⁿ subsets, including every one deeper than 2."
  - text: "Change the loop to for i in start..<2."
    correct: false
    why: "That limits which elements can be chosen (only the first two), not how many."
  - text: "Change explore(from: i + 1) to explore(from: i + 2)."
    correct: false
    why: "That skips neighbors, so [a, b] would never be produced. The size isn't controlled at all."
solution: |
  Record at size 2 and return. The early `return` is the important half: it stops the search at depth 2, so the work is proportional to the C(n, 2) results (plus the nodes on the way to them), not to 2ⁿ. Filtering afterwards is correct but does all the work anyway, which for 25 elements means 33 million subsets to keep 300.
````

````exercise
id: m18-l02-e2
type: prediction
prompt: Predict the exact output. The function records only full-length results.
code: |
  func arrangements(_ letters: [String]) -> [String] {
      var results: [String] = []
      var current = ""
      var used = Array(repeating: false, count: letters.count)

      func explore() {
          if current.count == letters.count {
              results.append(current)
              return
          }
          for i in letters.indices where !used[i] {
              used[i] = true
              current += letters[i]
              explore()
              current.removeLast()
              used[i] = false
          }
      }

      explore()
      return results
  }

  print(arrangements(["x", "y", "z"]))
  print(arrangements(["x", "y", "z", "w"]).count)
output: |
  ["xyz", "xzy", "yxz", "yzx", "zxy", "zyx"]
  24
hints:
  - The first choice loops over x, y, z in order, and everything starting with x is finished before y is tried.
  - "For each first letter, the remaining two letters appear in both orders, earlier index first."
solution: |
  ```output
  ["xyz", "xzy", "yxz", "yzx", "zxy", "zyx"]
  24
  ```

  It's the permutations function with a `String` as the partial answer. `current += letters[i]` chooses, `current.removeLast()` removes the last character, which undoes it. The order is depth first: all permutations starting with `x` (in the order of the remaining letters), then `y`, then `z`. Four letters give 4! = 24.
````

````exercise
id: m18-l02-e3
type: fill-in
prompt: Complete the combinations function so it returns every selection of k elements, in index order.
code: |
  func combinations(of items: [Int], size k: Int) -> [[Int]] {
      var results: [[Int]] = []
      var current: [Int] = []

      func explore(from start: Int) {
          if current.count == k {
              results.append(current)
              return
          }
          for i in [[1]]..<items.count {
              current.append(items[i])
              explore(from: [[2]])
              current.[[3]]
          }
      }

      explore(from: 0)
      return results
  }
blanks:
  - id: "1"
    answers: ["start"]
  - id: "2"
    answers: ["i + 1", "i+1"]
  - id: "3"
    answers: ["removeLast()", "removeLast ()"]
solution: |
  ```swift
  func combinations(of items: [Int], size k: Int) -> [[Int]] {
      var results: [[Int]] = []
      var current: [Int] = []

      func explore(from start: Int) {
          if current.count == k {
              results.append(current)
              return
          }
          for i in start..<items.count {
              current.append(items[i])
              explore(from: i + 1)
              current.removeLast()
          }
      }

      explore(from: 0)
      return results
  }

  print(combinations(of: [1, 2, 3, 4], size: 3))
  ```

  ```output
  [[1, 2, 3], [1, 2, 4], [1, 3, 4], [2, 3, 4]]
  ```

  - `start`: only offer elements after the last one chosen, so each selection appears once.
  - `i + 1`: the next level starts after the element just chosen. `start + 1` is a common slip; it would let later levels reuse elements in a different order.
  - `removeLast()`: undo the choice before trying the next `i`.
````

````exercise
id: m18-l02-e4
type: find-errors
prompt: |
  This should print the 4 subsets of `[1, 2]`. Which statements about it are true?
code: |
  func subsets(_ items: [Int]) -> [[Int]] {
      var results: [[Int]] = []
      var current: [Int] = []

      func explore(from start: Int) {
          results.append(current)
          for i in 0..<items.count {
              current.append(items[i])
              explore(from: i + 1)
          }
      }

      explore(from: 0)
      return results
  }
choices:
  - text: "The loop ignores start, so elements already passed are offered again."
    correct: true
    why: "start is passed down but never used. Every call loops over the whole array."
  - text: "There's no removeLast, so choices are never undone."
    correct: true
    why: "Every append stays in current for the rest of the search."
  - text: "Because the loop ignores start, the recursion never ends."
    correct: true
    why: "Every call loops over all of items, so every call makes at least one more call, forever. It ends with a stack overflow, not an answer."
  - text: "results.append(current) records references that later change."
    correct: false
    why: "current is an array, a value. Each append records a snapshot. The bug is in the loop, not in recording."
rubric:
  - I found that start is unused and explained the consequence (repeats, and no way to stop).
  - I found the missing unchoose.
  - I wrote the corrected loop.
solution: |
  Two bugs, and the first one is fatal. With `0..<items.count`, the range never becomes empty, so there's no base case: every call recurses again, and the program crashes with a stack overflow. Even if it stopped, the missing `removeLast()` would make `current` grow forever. The fixed loop:

  ```swift
  func subsets(_ items: [Int]) -> [[Int]] {
      var results: [[Int]] = []
      var current: [Int] = []

      func explore(from start: Int) {
          results.append(current)
          for i in start..<items.count {
              current.append(items[i])
              explore(from: i + 1)
              current.removeLast()
          }
      }

      explore(from: 0)
      return results
  }

  print(subsets([1, 2]))
  ```

  ```output
  [[], [1], [1, 2], [2]]
  ```

  The start index is doing two jobs here: it prevents repeated selections, and it's what makes the recursion end, because `start` grows on every level until the range is empty.
````

````exercise
id: m18-l02-e5
type: solve
prompt: |
  Write `func caseVariants(of text: String) -> [String]` that returns every string you can get by changing the case of each letter in `text` independently. Digits and other characters stay as they are. Keep the order where, at each letter, the lowercase choice comes first.

  Print the variants of `"a1b"`, `"42"` and `"3z4"`, then the number of variants of `"Swf"`:

  ```output
  ["a1b", "a1B", "A1b", "A1B"]
  ["42"]
  ["3z4", "3Z4"]
  8
  ```
starter: |
  func caseVariants(of text: String) -> [String] {
      let characters = Array(text)
      var results: [String] = []
      var current = ""

      func explore(at index: Int) {
          // Base case: every character placed
          // A letter: two choices. Anything else: one.
      }

      explore(at: 0)
      return results
  }
hints:
  - "Turn the string into an Array of Character so you can index it."
  - "Character has isLetter, lowercased() and uppercased(). The last two return a String."
  - "For a letter, choose lowercase, explore, unchoose, then choose uppercase, explore, unchoose."
rubric:
  - The function records a result only when every character has been placed.
  - Letters branch into two choices, other characters into one, and each choice is undone.
  - The output matches, and I stated the cost as O(n · 2ᴸ) for L letters.
solution: |
  ```swift
  func caseVariants(of text: String) -> [String] {
      let characters = Array(text)
      var results: [String] = []
      var current = ""

      func explore(at index: Int) {
          if index == characters.count {
              results.append(current)
              return
          }
          let character = characters[index]
          if character.isLetter {
              for option in [character.lowercased(), character.uppercased()] {
                  current += option
                  explore(at: index + 1)
                  current.removeLast()
              }
          } else {
              current.append(character)
              explore(at: index + 1)
              current.removeLast()
          }
      }

      explore(at: 0)
      return results
  }

  print(caseVariants(of: "a1b"))
  print(caseVariants(of: "42"))
  print(caseVariants(of: "3z4"))
  print(caseVariants(of: "Swf").count)
  ```

  ```output
  ["a1b", "a1B", "A1b", "A1B"]
  ["42"]
  ["3z4", "3Z4"]
  8
  ```

  The decision tree branches only at letters: "a1b" has two letters, so 2² = 4 variants. With L letters and n characters, there are 2ᴸ results of length n each, so **O(n · 2ᴸ)** time. The `if` doesn't skip the unchoose for non-letters: `current.append(character)` is a choice too, with exactly one option. `Swf` starts with an uppercase S, but the function generates both cases of every letter regardless of the input's case, so it's 2³ = 8.
````

````exercise
id: m18-l02-e6
type: explain
prompt: |
  A teammate converts the subsets generator to use a `final class Selection { var items: [Int] = [] }` as the partial answer "to avoid copying arrays", and appends the `Selection` object to `results`. Every result comes out empty. Explain what happened, and give two ways to fix it that keep the mutate-and-undo style.
rubric:
  - I explained that results holds many references to one object, which ends up empty after every choice is undone.
  - I explained that an array partial answer avoided this because appending a value stores a snapshot.
  - "I gave fixes such as appending selection.items (a value copy) instead of the object, or going back to a [Int] partial answer."
  - I noted that the copy at record time is unavoidable and isn't what the teammate was trying to save.
solution: |
  `results.append(selection)` stores a **reference**. All 2ⁿ entries point to the same object, and by the time you print them, every choice has been undone, so that one object's `items` is empty. You see `[]` 2ⁿ times. The lesson's block with `Path` shows exactly this: `[[], [], [], []]`.

  With `var current: [Int]`, `results.append(current)` stores a **value**. Copy-on-write means no copy happens until `current` is mutated next, and then the stored result keeps the old contents. Each result is a snapshot.

  Fixes that keep mutate-and-undo:
  1. Record a value: `results.append(selection.items)`. The class is still the shared state; the result is a copy of its contents.
  2. Use `var current: [Int]` again. Mutating it with `append`/`removeLast` doesn't copy anything; the only copies happen at record time, and those are unavoidable, since each result needs its own storage.

  The teammate's goal was based on a wrong premise: the mutating array version doesn't copy on each choice. The copies they wanted to avoid are the results themselves.
````

## Summary

- Backtracking = **choose, explore, unchoose** over one shared partial answer. When a call returns, the state is exactly what it was before the choice.
- Three questions define a problem: what's the partial answer, what are the choices, when is it complete.
- **Subsets**: record every node, loop from `start`, recurse with `i + 1`. 2ⁿ results. **Combinations**: the same, but record and return at size k. C(n, k) results. **Permutations**: loop over everything, skip what's `used`, record at size n. n! results.
- The output order is a depth-first walk of the decision tree.
- Copy per call (`current + [x]`) needs no undo and costs O(length) per choice; mutate and undo (`append`/`removeLast`, or `inout`) is O(1) per choice. Check that the state ends empty.
- Recording an array stores a snapshot; recording a class instance stores a reference to state that keeps changing.
- Generating everything costs at least the number of results: O(n · 2ⁿ) for subsets, O(n · n!) for permutations. Depth is only n.
