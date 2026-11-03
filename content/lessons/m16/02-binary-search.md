---
id: m16-l02
title: Binary search in practice
description: You rewrite binary search to find a boundary instead of a match, with a half-open range and an invariant you can check; use it for the first and last occurrence, counts and insertion points; search on any monotonic condition, including the answer to an optimization problem; and recognize the off-by-one bugs that make binary searches loop forever or crash.
module: m16
order: 2
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m16-l01]
objectives:
  - Write lower bound and upper bound with a half-open range, and state the invariant each keeps.
  - Find the first and last occurrence of a value, count occurrences and find the insertion point in O(log n).
  - Recognize a problem as a binary search over a monotonic yes/no condition, including "the smallest value that works".
  - "Diagnose the classic off-by-one bugs: mixed range conventions, low = mid, and reading past the end after the loop."
  - Test a binary search against a linear reference on arrays with duplicates.
terms:
  - term: Lower bound
    definition: The first index whose element is greater than or equal to the target, or count if there's none. It's where the target is, or where it would go.
  - term: Upper bound
    definition: The first index whose element is strictly greater than the target, or count. Upper bound minus lower bound is the number of copies of the target.
  - term: Half-open range
    definition: "A range [low, high) that includes low and excludes high, like Swift's low..<high. Empty when low == high."
  - term: Monotonic condition
    definition: A yes/no question about elements (or candidate answers) that is false for a prefix and true for everything after it, never switching back. Binary search finds the switch point.
  - term: Binary search on the answer
    definition: Searching the range of possible answers instead of an array, when "does this value work?" is monotonic. Common for "the smallest capacity that's enough" problems.
mastery:
  - Write lowerBound and upperBound from memory and trace them with a table.
  - Return the first and last index of a value, or nil, using the bounds.
  - Count the elements in a value range of a sorted array in O(log n).
  - Turn "the smallest X such that…" into a binary search over X with a feasibility function, and state its cost.
  - Spot low = mid with a rounded-down mid, and a high that starts at count − 1 in a half-open search.
resources: [swift-array, swift-book-control-flow, swift-book-closures, swift-book-generics]
cards:
  - id: m16-l02-c1
    front: What does lowerBound(of target, in sorted) return?
    back: The first index i with sorted[i] >= target, or count if every element is smaller. If the target is present, it's its first occurrence; if not, it's where the target would be inserted.
  - id: m16-l02-c2
    front: What's the invariant of the half-open lower-bound search?
    back: "Everything before low is < target, and everything from high on is >= target. The unknown part is [low, high). When low == high, the unknown part is empty and low is the boundary."
  - id: m16-l02-c3
    front: How do you count the copies of x in a sorted array in O(log n)?
    back: upperBound(x) − lowerBound(x). Two binary searches, each O(log n), however many copies there are. Scanning outward from one match would be O(k) for k copies.
  - id: m16-l02-c4
    front: When can you binary search over possible answers instead of an array?
    back: When the question "does answer x work?" is monotonic, false up to some value and true from there on, and you can check it. Cost is O(log(range) × cost of one check).
  - id: m16-l02-c5
    front: Why does low = mid loop forever when mid rounds down?
    back: "With high = low + 1, mid = low. If the branch sets low = mid, nothing changes, and the next pass is identical. In a lower-bound search, the side that excludes mid must move past it: low = mid + 1."
---

## The idea in one sentence

The useful version of binary search doesn't look for a match: it looks for **the boundary** where a yes/no condition switches from false to true, and almost every binary search problem is that boundary in disguise.

## From "find it" to "find the boundary"

Module 15's binary search returns *some* index of the target. On `[1, 3, 3, 3, 5, 8]`, searching for 3 lands on index 2, the middle copy. That's fine for "is it there?", and useless for:

- "Where's the **first** 3?" (index 1)
- "How many 3s are there?" (3)
- "Where would 4 go to keep the array sorted?" (index 4)

All three are about the same thing. Ask, for every element, "is it `>= target`?". In a sorted array the answers are a block of `false` followed by a block of `true`:

| index | 0 | 1 | 2 | 3 | 4 | 5 |
| --- | --- | --- | --- | --- | --- | --- |
| value | 1 | 3 | 3 | 3 | 5 | 8 |
| `value >= 3` | false | true | true | true | true | true |
| `value > 3` | false | false | false | false | true | true |

The first `true` in the `>= 3` row is the **lower bound**: index 1. The first `true` in the `> 3` row is the **upper bound**: index 4. The 3s live in between, `1..<4`, and there are 4 − 1 = 3 of them. If there were no 3s, both bounds would be the same index, the place a 3 would go.

### Lower bound

```swift
func lowerBound(of target: Int, in sorted: [Int]) -> Int {
    var low = 0
    var high = sorted.count
    while low < high {
        let mid = low + (high - low) / 2
        if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}

let values = [1, 3, 3, 3, 5, 8]
for target in [3, 4, 0, 9] {
    print("lowerBound(\(target)) = \(lowerBound(of: target, in: values))")
}
```

```output
lowerBound(3) = 1
lowerBound(4) = 4
lowerBound(0) = 0
lowerBound(9) = 6
```

It differs from Module 15's version in three places, and each one follows from a single choice: the range is **half-open**, `[low, high)`, like Swift's `low..<high`.

1. `high = sorted.count`, not `count - 1`. The answer can be `count` ("everything is smaller; it goes at the end"), so `count` has to be a possible result.
2. `while low < high`. A half-open range is empty when `low == high`, and that's when the search is over.
3. No `==` branch, and `high = mid` instead of `mid - 1`. When `sorted[mid] >= target`, `mid` **might be** the answer, so it stays in the candidate range as its upper edge.

The invariant: **everything before `low` is `< target`, and everything from `high` on is `>= target`.** At the start, both of those regions are empty, so it's true. Each pass shrinks the unknown middle and keeps it true: if `sorted[mid] < target`, then so is everything before `mid` (sorted), and `low = mid + 1` moves the "smaller" region forward to include `mid`. Otherwise `mid` and everything after it are `>= target`, and `high = mid` grows the "at least" region down to `mid`. When `low == high`, no unknown part is left, and `low` is exactly where the smaller region ends.

Termination: while `low < high`, `mid` rounds down, so `low <= mid < high`. Both branches make the range strictly smaller: `mid + 1 > low` and `mid < high`. So the loop ends, after about log₂ n passes: **O(log n) time, O(1) extra space.**

Trace for target 4:

| Pass | low | high | mid | sorted[mid] | Decision |
| --- | --- | --- | --- | --- | --- |
| 1 | 0 | 6 | 3 | 3 | 3 < 4, low = 4 |
| 2 | 4 | 6 | 5 | 8 | 8 ≥ 4, high = 5 |
| 3 | 4 | 5 | 4 | 5 | 5 ≥ 4, high = 4 |
| end | 4 | 4 | | | return 4 |

The loop never checks whether it found 4. It finds the boundary, and the caller decides what the boundary means.

### Upper bound, first, last and count

Upper bound is the same search with `<=` in the comparison: "keep moving right past everything `<= target`". With both bounds, the rest is arithmetic:

```swift
func lowerBound(of target: Int, in sorted: [Int]) -> Int {
    var low = 0
    var high = sorted.count
    while low < high {
        let mid = low + (high - low) / 2
        if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}

func upperBound(of target: Int, in sorted: [Int]) -> Int {
    var low = 0
    var high = sorted.count
    while low < high {
        let mid = low + (high - low) / 2
        if sorted[mid] <= target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}

func firstIndex(of target: Int, in sorted: [Int]) -> Int? {
    let index = lowerBound(of: target, in: sorted)
    return index < sorted.count && sorted[index] == target ? index : nil
}

func lastIndex(of target: Int, in sorted: [Int]) -> Int? {
    let index = upperBound(of: target, in: sorted) - 1
    return index >= 0 && sorted[index] == target ? index : nil
}

func occurrences(of target: Int, in sorted: [Int]) -> Int {
    upperBound(of: target, in: sorted) - lowerBound(of: target, in: sorted)
}

let values = [1, 3, 3, 3, 5, 8]
for target in [3, 4, 8, 0] {
    let first = firstIndex(of: target, in: values).map(String.init) ?? "nil"
    let last = lastIndex(of: target, in: values).map(String.init) ?? "nil"
    print("\(target): first \(first), last \(last), count \(occurrences(of: target, in: values))")
}
```

```output
3: first 1, last 3, count 3
4: first nil, last nil, count 0
8: first 5, last 5, count 1
0: first nil, last nil, count 0
```

`firstIndex` checks two things about the lower bound: that it's a real index (`< count`) and that the element there **is** the target, not just the next bigger value. `lastIndex` steps back from the upper bound and checks `>= 0` for the case where every element is bigger. The `&&` short-circuits, so the subscript only runs when the index is valid.

`occurrences` is two binary searches: **O(log n)** no matter how many copies there are. The tempting alternative, finding one match and walking left and right, costs O(k) for k copies, which is O(n) for an array that's mostly one value.

### Testing against a linear reference

Binary searches are short and full of `+ 1`s. Don't trust one until it has agreed with a linear version on arrays with duplicates, on every target from below the smallest to above the largest:

```swift
func lowerBound(of target: Int, in sorted: [Int]) -> Int {
    var low = 0
    var high = sorted.count
    while low < high {
        let mid = low + (high - low) / 2
        if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}

var checks = 0
var failures = 0
for length in 0...12 {
    let sorted = (0..<length).map { index in (index * 7 % 5) }.sorted()
    for target in -1...5 {
        let expected = sorted.firstIndex { value in value >= target } ?? sorted.count
        checks += 1
        if lowerBound(of: target, in: sorted) != expected {
            failures += 1
        }
    }
}
print("\(checks) checks, \(failures) failures")
```

```output
91 checks, 0 failures
```

The arrays have lengths 0 to 12 and values 0 to 4, so every array longer than 5 has duplicates. The linear reference, `firstIndex(where:)` with `?? count`, is the definition of lower bound written as an O(n) scan.

## Insertion points

A leaderboard keeps scores sorted. To add a new score, find where it goes with a binary search and insert there:

```swift
func upperBound(of target: Int, in sorted: [Int]) -> Int {
    var low = 0
    var high = sorted.count
    while low < high {
        let mid = low + (high - low) / 2
        if sorted[mid] <= target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}

var scores = [40, 55, 55, 70, 90]
for newScore in [55, 10, 95] {
    scores.insert(newScore, at: upperBound(of: newScore, in: scores))
}
print(scores)
```

```output
[10, 40, 55, 55, 55, 70, 90, 95]
```

Upper bound puts a new score **after** equal ones, so among ties the earliest arrival stays first. That matters when the elements are records sorted by score, not bare numbers. Lower bound would put it before them.

Costs: finding the spot is O(log n), but `insert(_:at:)` shifts every later element and is O(n), according to Apple's documentation. So each insertion is O(n). That still beats appending and re-sorting, which is O(n log n) per insertion. If you insert much more often than you read the sorted order, a different structure (a heap or a balanced tree, Module 19) is the better tool.

## Any monotonic condition

Nothing in lower bound depends on numbers. It finds the first `true` of **any** condition that is false for a prefix and true from then on. Written once, with the condition as a closure:

```swift
func firstTrue<Element>(in values: [Element], _ condition: (Element) -> Bool) -> Int {
    var low = 0
    var high = values.count
    while low < high {
        let mid = low + (high - low) / 2
        if condition(values[mid]) {
            high = mid
        } else {
            low = mid + 1
        }
    }
    return low
}

let releaseYears = [2014, 2016, 2016, 2019, 2021, 2024]
print(firstTrue(in: releaseYears) { year in year >= 2017 })

let names = ["Ana", "Bea", "Carlos", "Diego", "Elena"]
print(firstTrue(in: names) { name in name >= "C" })

let builds = [false, false, false, true, true]
print(firstTrue(in: builds) { isBroken in isBroken })
```

```output
3
2
3
```

The third call is the "first broken build" problem: commits in order, and once a bug is introduced, every later build is broken. It's what `git bisect` does for you: with 1,000 commits, about 10 builds instead of up to 1,000.

The requirement is the shape, not the type: **the condition must never go from true back to false.** On a list that isn't partitioned that way, `firstTrue` returns a meaningless index, just as Module 15's search did on an unsorted array. The standard library has no binary search, but the Swift Algorithms package, a separate open-source package from Apple, provides this operation as `partitioningIndex(where:)`.

## Binary search on the answer

Sometimes there's no array to search, only a range of possible answers. A podcast app downloads a queue of episodes **in order** and has a daily data cap. What's the smallest daily cap that gets the whole queue downloaded within d days? An episode can't be split across days.

How to recognize it: **"the smallest (or largest) value such that something is possible"**, where checking one candidate is easy and a bigger candidate never makes it harder. If a cap of 900 MB works, 901 MB works too: the condition "this cap fits in d days" is false up to some cap and true from there on. That's monotonic, so binary search applies to the caps themselves.

Two pieces:

1. **A feasibility check**: given a cap, how many days does the queue take? Fill each day greedily until the next episode doesn't fit. O(n).
2. **A search range**: the cap must be at least the largest episode (or it never downloads), and the total of all episodes always works (one day).

```swift
func daysNeeded(_ sizes: [Int], cap: Int) -> Int {
    var days = 1
    var usedToday = 0
    for size in sizes {
        if usedToday + size > cap {
            days += 1
            usedToday = 0
        }
        usedToday += size
    }
    return days
}

func smallestDailyCap(_ sizes: [Int], days: Int) -> (cap: Int, checks: Int)? {
    guard let largest = sizes.max(), days > 0 else { return nil }
    var low = largest
    var high = sizes.reduce(0, +)
    var checks = 0
    while low < high {
        let mid = low + (high - low) / 2
        checks += 1
        if daysNeeded(sizes, cap: mid) <= days {
            high = mid
        } else {
            low = mid + 1
        }
    }
    return (low, checks)
}

let episodes = [300, 500, 200, 400, 600, 100]
for days in [1, 3, 6] {
    if let result = smallestDailyCap(episodes, days: days) {
        print("d = \(days): cap \(result.cap) MB after \(result.checks) checks")
    }
}
```

```output
d = 1: cap 2100 MB after 10 checks
d = 3: cap 800 MB after 11 checks
d = 6: cap 600 MB after 11 checks
```

The search is `firstTrue` over the integers from `largest` to `total`, with `daysNeeded(cap) <= days` as the condition. For 3 days, a cap of 800 splits the queue into 300 + 500, 200 + 400, 600 + 100; at 799, 300 + 500 no longer fits on day one and the queue needs 4 days.

Cost: the range has `total − largest + 1` candidates, here 1,501, and the search checks about log₂ 1,501 ≈ 10.6 of them: 10 or 11 checks, depending on which way the halvings round. Each check is O(n). With S the total size, that's **O(n log S) time and O(1) extra space**. The naive version, trying every cap from `largest` upward until one works, is O(n · S) in the worst case: 1,501 checks here instead of 11.

The greedy `daysNeeded` is correct because the order is fixed: putting an episode on today's download whenever it fits can never make a later day's job harder. Module 20 covers when greedy choices like this are safe.

## Off-by-one bugs, and how they look

Every binary search bug is a mismatch between the range convention and one of the lines. Pick a convention and make every line agree with it. The two conventions:

| | Inclusive `[low, high]` (Module 15) | Half-open `[low, high)` (this lesson) |
| --- | --- | --- |
| Start | `high = count - 1` | `high = count` |
| Loop | `while low <= high` | `while low < high` |
| Shrink from above | `high = mid - 1` | `high = mid` |
| Shrink from below | `low = mid + 1` | `low = mid + 1` |
| Best for | "find this exact value" | "find the boundary" |

**Mixing them** gives a search that's right most of the time. Here's lower bound with the inclusive start but the half-open loop:

```swift
func lowerBoundMixed(of target: Int, in sorted: [Int]) -> Int {
    var low = 0
    var high = sorted.count - 1
    while low < high {
        let mid = low + (high - low) / 2
        if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}

let values = [1, 3, 5]
print(lowerBoundMixed(of: 3, in: values))
print(lowerBoundMixed(of: 9, in: values))
print(lowerBoundMixed(of: 4, in: [Int]()))
```

```output
1
2
0
```

The first answer is right. For 9 it returns 2 instead of 3: `count` can never come out, because `high` started below it. An insertion would put 9 **before** 5. The empty case happens to return 0, which is right by luck.

**Setting `low = mid`** when `mid` rounds down can make the loop stop shrinking. This version caps the passes at 10 so it can show the problem instead of hanging:

```swift
let sorted = [2, 4]
let target = 4
var low = 0
var high = sorted.count
var passes = 0
while low < high && passes < 10 {
    passes += 1
    let mid = low + (high - low) / 2
    if sorted[mid] < target {
        low = mid
    } else {
        high = mid
    }
}
print("passes: \(passes), low: \(low), high: \(high)")
```

```output
passes: 10, low: 0, high: 1
```

After the first pass, `low = 0` and `high = 1`, so `mid` is 0, `sorted[0] < 4`, and `low = mid` sets `low` to 0 again. Without the cap, this loop never ends. The rule: the branch that rules `mid` **out** must move past it.

**Reading at the bound without checking it.** Lower bound can return `count`. Using it as an index straight away crashes when every element is smaller than the target:

```swift runtime-error Index out of range
func lowerBound(of target: Int, in sorted: [Int]) -> Int {
    var low = 0
    var high = sorted.count
    while low < high {
        let mid = low + (high - low) / 2
        if sorted[mid] < target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low
}

let prices = [5, 9, 14]
let index = lowerBound(of: 20, in: prices)
print("index \(index)")
print("first price at or above 20: \(prices[index])")
```

```output
index 3
```

Check `index < sorted.count` before subscripting, as `firstIndex(of:in:)` above does.

## Common mistakes

> [!error] Using the Module 15 search for "first" or "count"
> A search that returns on `==` lands on whichever copy the midpoints hit. For the first occurrence, a count or an insertion point, search for the boundary with lower and upper bound.

> [!error] high = count − 1 in a half-open search
> The result can never be `count`, so "larger than everything" and "insert at the end" come out one too low. In a half-open search, `high` starts at `count`.

> [!error] low = mid with a rounded-down mid
> When `high == low + 1`, `mid == low`, and the range never shrinks. The side that excludes `mid` moves to `mid + 1`.

> [!error] Subscripting the result without a bounds check
> Lower and upper bound return `count` when nothing qualifies. `sorted[index]` then traps with `Index out of range`. Check `index < sorted.count` (and `index >= 0` after subtracting 1).

> [!error] A condition that isn't monotonic
> Binary search on a condition that goes false, true, false returns an index, just not a meaningful one. Before searching the answer space, convince yourself that if x works, every bigger x works too.

> [!error] A search range that excludes the answer
> For "smallest cap", starting `low` at 0 or 1 makes the search consider caps smaller than an episode. No number of days makes those work, but this `daysNeeded` doesn't know that: it gives the oversized episode a day of its own and reports a count as if it fit. Start at the largest single item, the smallest value that could possibly work.

## Exercises

````exercise
id: m16-l02-e1
type: comprehension
prompt: "With the lesson's lowerBound, what does lowerBound(of: 10, in: [2, 4, 6]) return?"
choices:
  - text: "3"
    correct: true
    why: Every element is smaller than 10, so the first index with an element >= 10 is one past the end, count.
  - text: "2"
    correct: false
    why: That's the index of the largest element. Lower bound returns where 10 would go, after 6.
  - text: "nil"
    correct: false
    why: lowerBound returns an Int, never nil. "Not present" is something the caller checks.
  - text: "It crashes with Index out of range"
    correct: false
    why: The search only reads sorted[mid], and mid is always below high, so it never reads at count. Only a caller that subscripts with the result would crash.
solution: |
  **3**, which is `count`. Lower bound answers "where does the first element `>= target` start?", and when there's none, the answer is the end of the array. That's also the insertion point: `insert(10, at: 3)` appends it. The search itself never reads `sorted[3]`: `mid` is always strictly less than `high`. The crash only happens if the caller treats the result as a valid index without checking.
````

````exercise
id: m16-l02-e2
type: prediction
prompt: Predict the exact output.
code: |
  func lowerBound(of target: Int, in sorted: [Int]) -> Int {
      var low = 0
      var high = sorted.count
      while low < high {
          let mid = low + (high - low) / 2
          if sorted[mid] < target {
              low = mid + 1
          } else {
              high = mid
          }
      }
      return low
  }

  func upperBound(of target: Int, in sorted: [Int]) -> Int {
      var low = 0
      var high = sorted.count
      while low < high {
          let mid = low + (high - low) / 2
          if sorted[mid] <= target {
              low = mid + 1
          } else {
              high = mid
          }
      }
      return low
  }

  let ratings = [2, 2, 5, 5, 5, 9]
  for target in [5, 2, 7, 10] {
      let lower = lowerBound(of: target, in: ratings)
      let upper = upperBound(of: target, in: ratings)
      print(target, lower, upper, upper - lower)
  }
output: |
  5 2 5 3
  2 0 2 2
  7 5 5 0
  10 6 6 0
hints:
  - Lower bound is the first index with a value >= target. Upper bound is the first with a value > target.
  - For a missing value, both bounds are the insertion point.
solution: |
  ```output
  5 2 5 3
  2 0 2 2
  7 5 5 0
  10 6 6 0
  ```

  The 5s occupy indexes 2, 3 and 4: lower bound 2, upper bound 5, three copies. The 2s are at 0 and 1. 7 isn't there and would go between 5 and 9, at index 5, so both bounds are 5 and the count is 0. 10 is larger than everything: both bounds are `count`, 6. `print` with several arguments separates them with spaces.
````

````exercise
id: m16-l02-e3
type: find-errors
prompt: This function should return the index of the **last** occurrence of `target` in a sorted array, or `nil`. Which statements are true?
code: |
  func lastOccurrence(of target: Int, in sorted: [Int]) -> Int? {
      var low = 0
      var high = sorted.count
      while low < high {
          let mid = low + (high - low) / 2
          if sorted[mid] <= target {
              low = mid + 1
          } else {
              high = mid
          }
      }
      return sorted[low - 1] == target ? low - 1 : nil
  }
choices:
  - text: "It crashes when every element is greater than the target, for example lastOccurrence(of: 1, in: [3, 4])."
    correct: true
    why: "The search returns 0, and sorted[-1] traps with Index out of range."
  - text: "It crashes on an empty array."
    correct: true
    why: The loop doesn't run, low is 0, and it reads sorted[-1].
  - text: "The loop is an upper bound search, which is the right search for the last occurrence."
    correct: true
    why: The last copy of the target is just before the first element that's greater than it.
  - text: "It returns the first occurrence instead of the last when there are duplicates."
    correct: false
    why: "With <=, the search moves past all copies of the target, so low - 1 is the last one. For [1, 3, 3, 3, 5] and 3 it returns 3."
  - text: "It can loop forever, because high = mid doesn't exclude mid."
    correct: false
    why: In a half-open range, high is already excluded. mid < high, so high = mid always shrinks the range.
rubric:
  - I identified that the search part is a correct upper bound.
  - I found that low - 1 can be -1 and is used as an index without a check.
  - I gave the two failing inputs (all greater, empty).
  - I fixed it with an index >= 0 check and tested the edge cases.
solution: |
  The search is a correct upper bound, and the idea (the last copy is just before the upper bound) is right. The bug is the return line: when nothing is `<= target`, `low` is 0, and `sorted[low - 1]` reads index -1. That happens for an empty array and whenever every element is greater than the target. The fix checks the index before reading:

  ```swift
  func lastOccurrence(of target: Int, in sorted: [Int]) -> Int? {
      var low = 0
      var high = sorted.count
      while low < high {
          let mid = low + (high - low) / 2
          if sorted[mid] <= target {
              low = mid + 1
          } else {
              high = mid
          }
      }
      let index = low - 1
      return index >= 0 && sorted[index] == target ? index : nil
  }

  let values = [1, 3, 3, 3, 5]
  print(lastOccurrence(of: 3, in: values) ?? -1)
  print(lastOccurrence(of: 4, in: values) ?? -1)
  print(lastOccurrence(of: 0, in: values) ?? -1)
  print(lastOccurrence(of: 5, in: values) ?? -1)
  print(lastOccurrence(of: 2, in: []) ?? -1)
  ```

  ```output
  3
  -1
  -1
  4
  -1
  ```

  `&&` short-circuits: when `index` is -1, the subscript never runs. 4 isn't present, and the element before the upper bound is 3, so the equality check returns `nil`.
````

````exercise
id: m16-l02-e4
type: fill-in
prompt: Complete `firstTrue` so it returns the index of the first element for which `condition` is true, in a list where the condition is false and then true. It should print `2 0 4`.
code: |
  func firstTrue<Element>(in values: [Element], _ condition: (Element) -> Bool) -> Int {
      var low = 0
      var high = [[1]]
      while low [[2]] high {
          let mid = low + (high - low) / 2
          if condition(values[mid]) {
              high = [[3]]
          } else {
              low = [[4]]
          }
      }
      return low
  }

  let sizes = [120, 340, 800, 950]
  print(firstTrue(in: sizes) { $0 > 500 }, firstTrue(in: sizes) { $0 > 0 }, firstTrue(in: sizes) { $0 > 1_000 })
blanks:
  - id: "1"
    answers: ["values.count"]
  - id: "2"
    answers: ["<"]
  - id: "3"
    answers: ["mid"]
  - id: "4"
    answers: ["mid + 1", "mid+1"]
solution: |
  ```swift
  func firstTrue<Element>(in values: [Element], _ condition: (Element) -> Bool) -> Int {
      var low = 0
      var high = values.count
      while low < high {
          let mid = low + (high - low) / 2
          if condition(values[mid]) {
              high = mid
          } else {
              low = mid + 1
          }
      }
      return low
  }

  let sizes = [120, 340, 800, 950]
  print(firstTrue(in: sizes) { $0 > 500 }, firstTrue(in: sizes) { $0 > 0 }, firstTrue(in: sizes) { $0 > 1_000 })
  ```

  ```output
  2 0 4
  ```

  Half-open throughout: `high` starts at `count` so "never true" can be the answer (4 here), the loop runs while the range `[low, high)` is non-empty, a true `mid` might be the first true one so it stays as the edge (`high = mid`), and a false `mid` is ruled out (`low = mid + 1`).
````

````exercise
id: m16-l02-e5
type: solve
prompt: |
  An orders screen has a filter "total between a and b" (both inclusive). The order totals are kept sorted. Write `func countInRange(_ sorted: [Int], from a: Int, to b: Int) -> Int` that returns how many totals fall in `a...b` in O(log n), using lower and upper bound. Return 0 when `a > b`.

  Expected output for the code in the starter:

  ```output
  4
  0
  7
  0
  ```
starter: |
  func countInRange(_ sorted: [Int], from a: Int, to b: Int) -> Int {
      // Two binary searches
      return 0
  }

  let totals = [5, 12, 12, 20, 33, 47, 60]
  print(countInRange(totals, from: 10, to: 35))
  print(countInRange(totals, from: 61, to: 100))
  print(countInRange(totals, from: 0, to: 60))
  print(countInRange(totals, from: 40, to: 30))
hints:
  - "The first total >= a is lowerBound(a). The first total > b is upperBound(b)."
  - The count is the distance between those two indexes.
rubric:
  - Uses lowerBound for a and upperBound for b.
  - Handles a > b without returning a negative count.
  - The output matches.
  - States O(log n) time and O(1) extra space.
solution: |
  ```swift
  func lowerBound(of target: Int, in sorted: [Int]) -> Int {
      var low = 0
      var high = sorted.count
      while low < high {
          let mid = low + (high - low) / 2
          if sorted[mid] < target {
              low = mid + 1
          } else {
              high = mid
          }
      }
      return low
  }

  func upperBound(of target: Int, in sorted: [Int]) -> Int {
      var low = 0
      var high = sorted.count
      while low < high {
          let mid = low + (high - low) / 2
          if sorted[mid] <= target {
              low = mid + 1
          } else {
              high = mid
          }
      }
      return low
  }

  func countInRange(_ sorted: [Int], from a: Int, to b: Int) -> Int {
      guard a <= b else { return 0 }
      return upperBound(of: b, in: sorted) - lowerBound(of: a, in: sorted)
  }

  let totals = [5, 12, 12, 20, 33, 47, 60]
  print(countInRange(totals, from: 10, to: 35))
  print(countInRange(totals, from: 61, to: 100))
  print(countInRange(totals, from: 0, to: 60))
  print(countInRange(totals, from: 40, to: 30))
  ```

  ```output
  4
  0
  7
  0
  ```

  The totals in `a...b` start at the first one `>= a` and end just before the first one `> b`. For 10...35: lower bound of 10 is 1 (the first 12), upper bound of 35 is 5 (47), and 5 − 1 = 4: 12, 12, 20, 33. With `a > b`, lower bound of 40 is 5 and upper bound of 30 is 4, so without the `guard` the answer would be −1. Two binary searches: **O(log n) time, O(1) extra space**, however many orders match. Filtering the array would be O(n).
````

````exercise
id: m16-l02-e6
type: design
prompt: |
  A photo app uploads a fixed list of photos in order and can run at most `k` upload batches. Each batch has a size limit in MB, the same for every batch, and a batch takes consecutive photos. A teammate wants to find the smallest limit that needs at most `k` batches and proposes trying limits 1, 2, 3, … until one works. Explain how to use binary search instead: what you search over, why binary search is valid here, where the range starts and ends, and the cost of both approaches with n photos and a total size of S MB.
rubric:
  - I said the search is over limits, not over the photo array.
  - I explained the monotonic property (if a limit works, every larger limit works).
  - "I gave the range: from the largest photo to the total size."
  - I described the O(n) feasibility check (fill each batch greedily, count batches).
  - "I stated O(n log S) for binary search and O(n · S) worst case for trying every limit."
solution: |
  It's the podcast problem with different names. **Search over the possible limits**, not over the photos.

  **Why binary search is valid**: the question "can I upload everything in at most k batches with limit L?" is monotonic. A larger limit never needs more batches, because any grouping that fits limit L also fits L + 1. So the answers are "no" for small limits and "yes" from some limit on, and binary search finds the first "yes".

  **The range**: the limit can't be smaller than the largest photo, or that photo never uploads. And the total size S always works, in one batch. Search from `largest` to `S`.

  **The check**: walk the photos in order, adding each to the current batch if it fits and starting a new batch if not, and count batches. That's O(n), and greedy filling is safe because the order is fixed: putting a photo in the current batch never makes later batches harder.

  **Cost**: binary search does about log₂ S checks, so O(n log S). Trying 1, 2, 3, … does up to S checks (starting at the largest photo saves a little, not the order of growth): O(n · S). With 500 photos totaling 2,000 MB, that's about 11 checks against up to 2,000.
````

## Summary

- Search for **the boundary**, not the match. Lower bound is the first index with `value >= target`; upper bound is the first with `value > target`. Both return `count` when nothing qualifies.
- The half-open search: `high = count`, `while low < high`, `high = mid` on one side, `low = mid + 1` on the other. Its invariant: everything before `low` fails the condition, everything from `high` on passes it.
- First occurrence: lower bound, if it's in range and equal. Last: upper bound − 1, if it's `>= 0` and equal. Count: upper − lower, **O(log n)** regardless of copies. Insertion point: either bound (upper keeps ties in arrival order), but the insert itself is O(n).
- Binary search works on **any monotonic condition**, and on **ranges of answers**: "the smallest X that works" is a binary search over X with a feasibility check, O(check × log(range)).
- The bugs are convention mismatches: `high = count - 1` with `<`, `low = mid` with a rounded-down `mid`, and subscripting the result without a bounds check. Test every binary search against a linear reference, on arrays with duplicates.
