---
id: m16-l06
title: Prefix sums
description: You precompute running totals once so that the sum of any range is a single subtraction, get the off-by-one right with a leading zero and half-open ranges, combine prefix sums with a dictionary to count subarrays with a given sum even when values are negative, apply many range updates at once with a difference array, and close the module by choosing between its six patterns.
module: m16
order: 6
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m16-l05]
objectives:
  - Build a prefix sum array with a leading zero and answer range-sum queries in O(1).
  - Convert between inclusive and half-open ranges without off-by-one errors.
  - Count or find subarrays with a given sum in O(n) average using prefix sums and a dictionary, including negative values.
  - Apply many range updates with a difference array and recover the values with one prefix pass.
  - Choose between linear traversal, binary search, two pointers, sliding window, hashing and prefix sums from a problem statement.
terms:
  - term: Prefix sum
    definition: "prefix[i] is the sum of the first i values: values[0] + … + values[i − 1]. prefix[0] is 0, and the array has count + 1 entries."
  - term: Range sum query
    definition: "A request for the sum of values in a range. With prefix sums, the sum of values[l..<r] is prefix[r] − prefix[l]."
  - term: Precomputation
    definition: Work done once, up front, so that many later queries are cheap. Prefix sums cost O(n) to build and make each query O(1).
  - term: Difference array
    definition: "An array where adding x to every value in l..<r is recorded as diff[l] += x and diff[r] −= x. A prefix sum over it gives back the values."
mastery:
  - Write the prefix array and the query prefix[r] − prefix[l] and check them against a direct sum.
  - Translate an inclusive range l...r into prefix[r + 1] − prefix[l].
  - "Count subarrays with sum k with a dictionary seeded with [0: 1], and explain why the seed is needed."
  - Find the longest subarray with sum k with an index map of first prefix positions.
  - Apply q range updates in O(n + q) with a difference array.
  - Name the pattern and its cost for a new problem statement.
resources: [swift-array, swift-dictionary, swift-book-collection-types, swift-book-control-flow]
cards:
  - id: m16-l06-c1
    front: How do you get the sum of values[l..<r] from a prefix array?
    back: "prefix[r] − prefix[l], where prefix[i] is the sum of the first i values and prefix[0] = 0. For an inclusive range l...r, it's prefix[r + 1] − prefix[l]."
  - id: m16-l06-c2
    front: Why does the prefix array have count + 1 entries?
    back: "prefix[0] = 0 is the sum of no values. It makes ranges that start at index 0 work with the same formula, prefix[r] − prefix[0], with no special case."
  - id: m16-l06-c3
    front: How do you count subarrays that sum to k in O(n)?
    back: "Walk once with a running prefix sum. A subarray ending here sums to k when an earlier prefix equals prefix − k, so add the count of such prefixes from a dictionary, then record the current prefix. Seed the dictionary with [0: 1] for subarrays that start at index 0."
  - id: m16-l06-c4
    front: Prefix sums or sliding window for "subarrays with sum k"?
    back: A sliding window only works when values can't be negative, because it assumes shrinking reduces the sum. Prefix sums with a dictionary work with any signs.
  - id: m16-l06-c5
    front: How do you add x to every value in l..<r, for many ranges, efficiently?
    back: "Difference array: diff[l] += x and diff[r] −= x for each update, O(1) each. Then one prefix pass recovers all values. O(n + q) instead of O(n · q)."
---

## The idea in one sentence

Add the values up once, keeping every running total, and the sum of **any** range becomes one subtraction: O(n) to prepare, then **O(1)** per question.

## When to think "prefix sums"

- **Many questions about sums over ranges** of data that doesn't change: "steps between day 40 and day 70", "revenue from March to June", asked again and again.
- **"Subarray with sum k"** (or "divisible by k", "balanced"), especially when values can be **negative**, which rules out the sliding window from lesson 4.
- **"Split point"** or **"balance index"**: where the total on the left equals the total on the right.
- **Many updates of the form "add x to every value in a range"**, followed by reading the result: the difference array, at the end of this lesson.

## The prefix array

Define `prefix[i]` as the sum of the **first i** values. So `prefix[0]` is 0 (the sum of nothing), `prefix[1]` is `values[0]`, and `prefix[count]` is the total. The array has **count + 1** entries.

| i | 0 | 1 | 2 | 3 | 4 | 5 |
| --- | --- | --- | --- | --- | --- | --- |
| values[i] | 3 | 1 | 4 | 1 | 5 | |
| prefix[i] | 0 | 3 | 4 | 8 | 9 | 14 |

The sum of `values[l..<r]` is everything before `r` minus everything before `l`:

**sum(l..<r) = prefix[r] − prefix[l]**

For `values[1..<4]`, which is 1 + 4 + 1 = 6: `prefix[4] − prefix[1]` = 9 − 3 = 6.

A fitness app answers "how many steps between these two days?" for any pair of days the user selects:

```swift
struct RangeSums {
    private let prefix: [Int]

    init(_ values: [Int]) {
        var prefix = [0]
        prefix.reserveCapacity(values.count + 1)
        for value in values {
            prefix.append(prefix[prefix.count - 1] + value)
        }
        self.prefix = prefix
    }

    func sum(_ range: Range<Int>) -> Int {
        prefix[range.upperBound] - prefix[range.lowerBound]
    }
}

let steps = [3_200, 8_100, 12_000, 4_500, 9_900, 7_300, 11_000]
let sums = RangeSums(steps)
print(sums.sum(0..<7))
print(sums.sum(2..<5))
print(sums.sum(3..<3))
print(sums.sum(2..<5) == steps[2..<5].reduce(0, +))
```

```output
56000
26400
0
true
```

1. `prefix` starts as `[0]`: the leading zero.
2. Each new entry is the previous entry plus the next value. After the loop, `prefix` has `values.count + 1` entries.
3. `sum(_:)` takes a half-open `Range<Int>` like `2..<5`, which matches the formula exactly: `upperBound` is the first index **not** included.
4. An empty range like `3..<3` gives 0 with no special case.
5. The last line checks one query against a direct sum. `steps[2..<5]` is an array slice, and `reduce(0, +)` adds it up in O(r − l).

**Costs**: building is **O(n) time and O(n) extra space**. Each query is **O(1)**. The naive alternative, summing the range for every query, costs O(r − l), up to O(n) per query. For q queries over n days: **O(n + q)** against **O(q · n)**. For a year of data and 1,000 queries from a chart that lets the user drag a range, that's about 1,365 operations against up to 365,000.

The leading zero is what keeps the formula uniform. Without it, a range starting at 0 needs `if l == 0 { return prefix[r - 1] }`, and that branch is where the off-by-one bugs live.

### Inclusive ranges

Users and problem statements often say "from day 2 to day 4, inclusive". That's `2...4`, which is the half-open `2..<5`. So:

**sum(l...r) = prefix[r + 1] − prefix[l]**

Convert to half-open once, at the edge of your code, and use one formula everywhere else.

> [!warning] Prefix sums are for data that doesn't change
> If a value changes, every prefix after it is wrong, and rebuilding is O(n). If updates and queries are interleaved, a Fenwick tree or a segment tree supports both in O(log n). Those are beyond this module.

## Subarrays with a given sum

A budgeting app records the daily change in an account: deposits are positive, spending negative. The question: **how many stretches of consecutive days had a net change of exactly 0?** (Days that "cancelled out".)

Lesson 4 showed that a sliding window breaks with negative values. Prefix sums don't care about signs.

**Naive version**: every start, every end, with a running sum per start. O(n²) time, O(1) extra space:

```swift
func countStretchesNaive(_ changes: [Int], summingTo target: Int) -> Int {
    var count = 0
    for start in changes.indices {
        var total = 0
        for end in start..<changes.count {
            total += changes[end]
            if total == target {
                count += 1
            }
        }
    }
    return count
}

print(countStretchesNaive([3, -3, 2, -2, 0, 5], summingTo: 0))
```

```output
6
```

**The pattern**: the stretch `l..<r` sums to `target` when `prefix[r] − prefix[l] == target`, that is, when **`prefix[l] == prefix[r] − target`**. So, walking `r` forward, the number of good stretches ending just before `r` is the number of **earlier** prefixes equal to `prefix[r] − target`. A dictionary from prefix value to how many times it has occurred so far answers that in one lookup:

```swift
func countStretches(_ changes: [Int], summingTo target: Int) -> Int {
    var seen: [Int: Int] = [0: 1]
    var prefix = 0
    var count = 0
    for change in changes {
        prefix += change
        count += seen[prefix - target, default: 0]
        seen[prefix, default: 0] += 1
    }
    return count
}

print(countStretches([3, -3, 2, -2, 0, 5], summingTo: 0))
print(countStretches([3, -3, 2, -2, 0, 5], summingTo: 5))
print(countStretches([], summingTo: 0))
```

```output
6
4
0
```

1. `seen` starts as `[0: 1]`: the empty prefix, before any day, has sum 0 and has "occurred" once. That's `prefix[0]` from the table, and it's what lets a stretch start at day 0.
2. `prefix` is the running total, the current `prefix[r]`. You don't need the whole array, only the count of each value.
3. `count += seen[prefix - target, default: 0]`: every earlier prefix equal to `prefix − target` is the start of one good stretch ending at this day.
4. Only **after** the lookup is the current prefix recorded. Recording it first would let a stretch start and end at the same point: an empty stretch, which with `target` 0 would count every day.

Trace for target 0 on `[3, -3, 2, -2, 0, 5]`:

| day | change | prefix | seen[prefix − 0] before | count | seen after |
| --- | --- | --- | --- | --- | --- |
| | | 0 | | 0 | 0: 1 |
| 0 | 3 | 3 | 0 | 0 | 0: 1, 3: 1 |
| 1 | −3 | 0 | 1 | 1 | 0: 2, 3: 1 |
| 2 | 2 | 2 | 0 | 1 | 0: 2, 3: 1, 2: 1 |
| 3 | −2 | 0 | 2 | 3 | 0: 3, 3: 1, 2: 1 |
| 4 | 0 | 0 | 3 | 6 | 0: 4, 3: 1, 2: 1 |
| 5 | 5 | 5 | 0 | 6 | 0: 4, 3: 1, 2: 1, 5: 1 |


The prefix 0 occurs four times (before any day, and after days 1, 3 and 4), and every pair of those occurrences bounds a stretch with net change 0: 4 × 3 / 2 = 6 stretches. The trace counts each pair when its second occurrence arrives: 1, then 2, then 3.

**Costs**: one pass with two O(1)-average dictionary operations per day: **O(n) time on average, O(n) extra space** for the dictionary (one entry per distinct prefix value). The naive version is O(n²) time and O(1) space: the same trade as Two Sum in Module 15, memory for time.

The same idea answers related questions by changing what the dictionary stores:

- **The longest** stretch with sum k: store the **first** index at which each prefix value occurred (an index map, as in lesson 5), and measure the distance to it.
- **Stretches whose sum is divisible by k**: two prefixes whose difference is divisible by k have the same remainder modulo k, so count remainders instead of prefix values. (Swift's `%` keeps the sign of the left operand, so with negative values, normalize with `((prefix % k) + k) % k`.)

## The reverse: difference arrays

Prefix sums turn "sum a range" into O(1). The **difference array** does the opposite trick: it turns "add x to a whole range" into O(1), as long as you only need to read the values after all the updates.

A small hotel app has bookings, each from a check-in night to a check-out night (the guest leaves in the morning, so the check-out night isn't occupied). How many rooms are occupied on each night?

**Naive version**: for each booking, add 1 to every night it covers. O(q · n) for q bookings over n nights; a long booking costs as many steps as nights it covers.

**The pattern**: record only where each booking **starts** and **stops** counting. `diff[checkIn] += 1` means "from this night on, one more room", and `diff[checkOut] -= 1` means "from this night on, one fewer". A prefix sum over `diff` turns those changes back into occupancy:

```swift
struct Booking {
    let checkIn: Int
    let checkOut: Int
}

func occupancy(_ bookings: [Booking], nights: Int) -> [Int] {
    var diff = Array(repeating: 0, count: nights + 1)
    for booking in bookings {
        diff[booking.checkIn] += 1
        diff[booking.checkOut] -= 1
    }
    var result: [Int] = []
    var occupied = 0
    for night in 0..<nights {
        occupied += diff[night]
        result.append(occupied)
    }
    return result
}

let bookings = [Booking(checkIn: 0, checkOut: 3), Booking(checkIn: 1, checkOut: 4),
                Booking(checkIn: 2, checkOut: 3), Booking(checkIn: 5, checkOut: 7)]
print(occupancy(bookings, nights: 7))
```

```output
[1, 2, 3, 1, 0, 1, 1]
```

1. `diff` has `nights + 1` entries so that a booking that checks out on the last day, `checkOut == nights`, has a slot to write into. That slot is never read.
2. Each booking is two O(1) updates, regardless of its length.
3. The running sum `occupied` at night i is the number of bookings that started at or before i minus those that ended at or before i: exactly the guests still there.

**Costs**: **O(n + q) time and O(n) extra space**, against O(q · n) for the naive version. Bookings are half-open ranges, `checkIn..<checkOut`, which is why the formula needs no `+ 1`. With an inclusive range `l...r`, the stop goes at `r + 1`.

## Choosing a pattern

This module's six patterns cover a large share of array and string problems. The statement usually tells you which one to try first:

| The statement says | Try | Typical cost |
| --- | --- | --- |
| best so far, first/any match, a run or streak, unsorted | Linear traversal (lesson 1) | O(n) time, O(1) space |
| sorted + first/last/count/insert, or "the smallest X that works" | Binary search (lesson 2) | O(log n), or O(n log S) on the answer |
| sorted + pairs, in place, merge, both ends | Two pointers (lesson 3) | O(n) time, O(1) space |
| contiguous + longest/shortest/k consecutive, non-negative values | Sliding window (lesson 4) | O(n) time |
| seen before, how many, same elements in any order, group | Hashing (lesson 5) | O(n) average time, O(n) space |
| many range sums, subarray sum with negatives, many range updates | Prefix sums, difference arrays (lesson 6) | O(n + q) |

They combine. "Count subarrays with sum k" is prefix sums **plus** hashing. "Longest substring without repeats" is a window **with** a set. When none fits, the honest O(n²) solution is a fine place to start, and the question becomes which repeated work it's doing.

## Common mistakes

> [!error] A prefix array without the leading zero
> With `prefix[i]` meaning "sum up to and including i", ranges starting at 0 need a special case, and the formula changes to `prefix[r] - prefix[l - 1]`, which reads `prefix[-1]` when `l` is 0. Use `count + 1` entries with `prefix[0] = 0`.

> [!error] Mixing inclusive and half-open ranges
> `l..<r` is `prefix[r] - prefix[l]`; `l...r` is `prefix[r + 1] - prefix[l]`. Convert to half-open at the boundary and use one formula inside.

> [!error] Forgetting to seed the dictionary with [0: 1]
> Without it, stretches that start at index 0 are never counted. `countStretches([5], summingTo: 5)` would return 0.

> [!error] Recording the prefix before looking it up
> The current prefix has to be added to the dictionary **after** the lookup. Otherwise, each position pairs with itself, counting an empty stretch; with a target of 0, every element adds one false match.

> [!error] Using prefix sums after the data changed
> A prefix array is a snapshot. After `values[i]` changes, every `prefix[j]` with `j > i` is stale. Rebuild it, or use a structure that supports updates.

## Exercises

````exercise
id: m16-l06-e1
type: comprehension
prompt: "prefix is the prefix array of values, with prefix[0] = 0 and count + 1 entries. Which expression is the sum of values[2], values[3] and values[4]?"
choices:
  - text: "prefix[5] - prefix[2]"
    correct: true
    why: "Indexes 2 to 4 inclusive are the half-open range 2..<5, so it's prefix[5] − prefix[2]."
  - text: "prefix[4] - prefix[2]"
    correct: false
    why: "That's 2..<4: values[2] and values[3] only."
  - text: "prefix[4] - prefix[1]"
    correct: false
    why: "That's 1..<4: values[1], values[2] and values[3]."
  - text: "prefix[5] - prefix[1]"
    correct: false
    why: "That's 1..<5, four values starting at values[1]."
solution: |
  **prefix[5] − prefix[2].** `prefix[5]` is the sum of `values[0]` to `values[4]`, and `prefix[2]` is the sum of `values[0]` and `values[1]`. The difference leaves exactly indexes 2, 3 and 4. The general rule for the inclusive range `l...r` is `prefix[r + 1] − prefix[l]`.
````

````exercise
id: m16-l06-e2
type: prediction
prompt: Predict the exact output.
code: |
  let values = [2, -1, 4, 0, -3, 5]
  var prefix = [0]
  for value in values {
      prefix.append(prefix[prefix.count - 1] + value)
  }
  print(prefix)
  print(prefix[3] - prefix[0], prefix[6] - prefix[2], prefix[4] - prefix[4])
output: |
  [0, 2, 1, 5, 5, 2, 7]
  5 6 0
hints:
  - Each entry is the previous one plus the next value.
  - "prefix[r] − prefix[l] is the sum of values[l..<r]."
solution: |
  ```output
  [0, 2, 1, 5, 5, 2, 7]
  5 6 0
  ```

  The running totals: 0, then 0 + 2 = 2, 2 − 1 = 1, 1 + 4 = 5, 5 + 0 = 5, 5 − 3 = 2, 2 + 5 = 7. Seven entries for six values. `prefix[3] − prefix[0]` is 2 − 1 + 4 = 5; `prefix[6] − prefix[2]` is 4 + 0 − 3 + 5 = 6; `prefix[4] − prefix[4]` is the empty range, 0. Negative values are no problem for prefix sums.
````

````exercise
id: m16-l06-e3
type: find-errors
prompt: This function should count the stretches of consecutive values that sum to `target`. Which statements are true?
code: |
  func countStretches(_ values: [Int], summingTo target: Int) -> Int {
      var seen: [Int: Int] = [:]
      var prefix = 0
      var count = 0
      for value in values {
          prefix += value
          seen[prefix, default: 0] += 1
          count += seen[prefix - target, default: 0]
      }
      return count
  }
choices:
  - text: "It never counts stretches that start at index 0, because seen doesn't start with [0: 1]."
    correct: true
    why: "countStretches([5], summingTo: 5) needs an earlier prefix of 0, and there's none."
  - text: "With target 0, it counts every element as a stretch, because the current prefix is recorded before the lookup."
    correct: true
    why: "prefix − 0 is the prefix just added, so each position matches itself."
  - text: "It fails for negative values, like a sliding window."
    correct: false
    why: Prefix sums with a dictionary don't depend on signs. The bugs are the seed and the order.
  - text: "It's O(n²) because of the dictionary inside the loop."
    correct: false
    why: Each dictionary operation is O(1) on average. It's O(n) on average.
rubric:
  - "I found the missing [0: 1] seed and gave an input that shows it."
  - I found that the update comes before the lookup and explained what it counts.
  - I fixed both and checked against a brute-force count.
solution: |
  Two bugs, and for some inputs they cancel out, which makes them hard to spot by testing a single case. Fixed:

  ```swift
  func countStretches(_ values: [Int], summingTo target: Int) -> Int {
      var seen: [Int: Int] = [0: 1]
      var prefix = 0
      var count = 0
      for value in values {
          prefix += value
          count += seen[prefix - target, default: 0]
          seen[prefix, default: 0] += 1
      }
      return count
  }

  func bruteForce(_ values: [Int], summingTo target: Int) -> Int {
      var count = 0
      for start in values.indices {
          var total = 0
          for end in start..<values.count {
              total += values[end]
              if total == target {
                  count += 1
              }
          }
      }
      return count
  }

  print(countStretches([5], summingTo: 5))
  print(countStretches([1, -1, 1], summingTo: 0))
  let sample = [2, -2, 3, 0, -3, 1, 2]
  print((-3...5).allSatisfy { countStretches(sample, summingTo: $0) == bruteForce(sample, summingTo: $0) })
  ```

  ```output
  1
  2
  true
  ```

  The seed `[0: 1]` stands for the empty prefix before the first value, so stretches starting at index 0 have something to pair with. Looking up before recording means a stretch always has at least one element. The last line compares with the O(n²) brute force for every target from −3 to 5.
````

````exercise
id: m16-l06-e4
type: fill-in
prompt: "A streaming service schedules promotions: each one adds a discount of `percent` to every day in `startDay...endDay` (inclusive). Complete the difference array so the function returns the total discount per day. It should print `[10, 10, 25, 15, 15, 0]`."
code: |
  func dailyDiscounts(_ promotions: [(startDay: Int, endDay: Int, percent: Int)], days: Int) -> [Int] {
      var diff = Array(repeating: 0, count: days + 1)
      for promotion in promotions {
          diff[promotion.startDay] += promotion.percent
          diff[[[1]]] -= promotion.percent
      }
      var result: [Int] = []
      var running = 0
      for day in 0..<days {
          running [[2]] diff[day]
          result.append(running)
      }
      return result
  }

  print(dailyDiscounts([(0, 2, 10), (2, 4, 15)], days: 6))
blanks:
  - id: "1"
    answers: ["promotion.endDay + 1", "promotion.endDay+1"]
  - id: "2"
    answers: ["+="]
solution: |
  ```swift
  func dailyDiscounts(_ promotions: [(startDay: Int, endDay: Int, percent: Int)], days: Int) -> [Int] {
      var diff = Array(repeating: 0, count: days + 1)
      for promotion in promotions {
          diff[promotion.startDay] += promotion.percent
          diff[promotion.endDay + 1] -= promotion.percent
      }
      var result: [Int] = []
      var running = 0
      for day in 0..<days {
          running += diff[day]
          result.append(running)
      }
      return result
  }

  print(dailyDiscounts([(0, 2, 10), (2, 4, 15)], days: 6))
  ```

  ```output
  [10, 10, 25, 15, 15, 0]
  ```

  The ranges are **inclusive**, so a promotion stops applying on the day **after** `endDay`: the subtraction goes at `endDay + 1`. That's why `diff` has `days + 1` entries: a promotion ending on the last day writes one past it. Day 2 gets both discounts, 10 + 15. Each promotion is O(1), and the final pass is O(days): O(days + promotions) in total.
````

````exercise
id: m16-l06-e5
type: solve
prompt: |
  A budgeting app wants the **longest** stretch of consecutive days whose net change is exactly 0. Write `func longestBalancedStretch(_ changes: [Int]) -> Int` in O(n) on average, using prefix sums and a dictionary from each prefix value to the **first** index where it occurred. Return 0 if there's none.

  Expected output for the starter's calls:

  ```output
  5
  0
  2
  0
  ```
starter: |
  func longestBalancedStretch(_ changes: [Int]) -> Int {
      var firstIndex: [Int: Int] = [0: -1]
      var prefix = 0
      var longest = 0
      // For each day, look up the first time this prefix value appeared
      return longest
  }

  print(longestBalancedStretch([3, -3, 2, -2, 0, 5]))
  print(longestBalancedStretch([1, 2, 3]))
  print(longestBalancedStretch([4, -4, 7]))
  print(longestBalancedStretch([]))
hints:
  - "Two equal prefix values at positions i and j mean the days after i up to j sum to 0: a stretch of j − i days."
  - "Seeding with [0: -1] says the empty prefix sits just before day 0, so a stretch from day 0 to day j has length j − (−1) = j + 1."
  - Only store a prefix value the first time you see it; later occurrences should measure against it.
rubric:
  - "Uses a dictionary from prefix value to its first index, seeded with [0: -1]."
  - Never overwrites an existing entry.
  - The output matches, including the empty array.
  - "States O(n) time on average and O(n) extra space, and compares with the O(n²) brute force."
solution: |
  ```swift
  func longestBalancedStretch(_ changes: [Int]) -> Int {
      var firstIndex: [Int: Int] = [0: -1]
      var prefix = 0
      var longest = 0
      for (day, change) in changes.enumerated() {
          prefix += change
          if let first = firstIndex[prefix] {
              longest = max(longest, day - first)
          } else {
              firstIndex[prefix] = day
          }
      }
      return longest
  }

  print(longestBalancedStretch([3, -3, 2, -2, 0, 5]))
  print(longestBalancedStretch([1, 2, 3]))
  print(longestBalancedStretch([4, -4, 7]))
  print(longestBalancedStretch([]))
  ```

  ```output
  5
  0
  2
  0
  ```

  If the running total is the same after day i and after day j, the days i + 1 through j cancel out: j − i days. To make that as long as possible, measure against the **first** time the total had this value, which is why existing entries are never overwritten. The seed `0: -1` handles stretches that start on day 0: in the first example, the total is 0 again after day 4, giving 4 − (−1) = 5 days (3, −3, 2, −2, 0).

  It's the index map from lesson 5 applied to prefix sums. **O(n) time on average, O(n) extra space**. The brute force over all start and end days is O(n²).
````

````exercise
id: m16-l06-e6
type: design
prompt: |
  For each statement, name the pattern from this module you'd try first, and give the time complexity you'd expect. Justify each choice with the words in the statement that point to it.

  1. "Given a sorted array of timestamps, return how many fall within the last hour."
  2. "Given an unsorted list of usernames, return the first one that appears more than once."
  3. "Given daily temperatures (which can be negative), answer 10,000 queries of the form 'average temperature between day a and day b'."
  4. "Given a string, return the length of the shortest substring that contains at least one of each vowel."
  5. "Given a sorted array, remove duplicates in place and return the new length."
rubric:
  - "1: binary search (sorted, count in a range), O(log n): two bounds."
  - "2: hashing with a Set (seen before, unsorted), O(n) average."
  - "3: prefix sums (many range queries, static data, negatives are fine), O(n + q)."
  - "4: sliding window, shortest-valid version, with counts of vowels (contiguous, shortest), O(n) average."
  - "5: two pointers, read/write (sorted, in place), O(n) time and O(1) space."
solution: |
  1. **Binary search**, O(log n). "Sorted" and "how many fall within" a range: lower bound of `now − 3600`, upper bound of `now`, and subtract. A linear scan would be O(n).
  2. **Hashing**, O(n) on average. "Unsorted" and "appears more than once" means "have I seen this before?": walk the list with a `Set`, and return the first name whose `insert` reports it was already there. Sorting would lose the original order that "first" depends on.
  3. **Prefix sums**, O(n + q). "10,000 queries" over "days a to b" of data that doesn't change. Build the prefix array once; each average is `(prefix[b + 1] − prefix[a]) / (b − a + 1)`. Negative temperatures don't matter. Summing each range directly would be O(q · n).
  4. **Sliding window**, shortest-valid version, O(n) on average. "Substring" means contiguous, and "shortest that contains" is a validity condition that only gets easier as the window grows. Keep a dictionary of vowel counts in the window; while all five are present, record the length and shrink from the left.
  5. **Two pointers**, read/write, O(n) time and O(1) extra space. "Sorted" and "in place": a reader walks every element and a writer keeps one copy of each value.
````

## Summary

- `prefix[i]` is the sum of the first i values; `prefix[0] = 0`, and the array has `count + 1` entries. **sum(l..<r) = prefix[r] − prefix[l]**, and sum(l...r) = prefix[r + 1] − prefix[l]. O(n) to build, **O(1)** per query, so q queries cost O(n + q) instead of O(q · n).
- Prefix sums are a snapshot: after the data changes, rebuild.
- **Subarrays with sum k**: a stretch `l..<r` works when `prefix[l] == prefix[r] − k`. Count earlier prefixes with a dictionary seeded with `[0: 1]`, looking up before recording. O(n) on average, and it works with negative values, unlike a sliding window. For the longest such stretch, store first indexes, seeded with `[0: -1]`.
- **Difference arrays** reverse the trick: a range update is two O(1) writes, and one prefix pass recovers the values. O(n + q).
- The module's patterns, by signal: best so far → **traversal**; sorted + boundary → **binary search**; sorted, pairs or in place → **two pointers**; contiguous and non-negative → **sliding window**; seen, counts, groups → **hashing**; many range sums or negatives → **prefix sums**. They combine, and the honest O(n²) is a fine first step.
