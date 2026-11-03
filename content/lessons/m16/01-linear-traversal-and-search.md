---
id: m16-l01
title: Linear traversal and linear search
description: You answer array questions in a single pass by choosing the state to carry from one element to the next, write the invariant that makes the pass correct, turn an O(n²) comparison of every pair into an O(n) running minimum, and avoid the empty-input and neighbor-loop bugs that one-pass code attracts.
module: m16
order: 1
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m15-l06]
objectives:
  - Recognize problems that one pass with a few variables can answer, and the ones that need more.
  - Choose the state a traversal carries and write its invariant in one sentence.
  - Replace an O(n²) check of every pair with an O(n) pass that remembers the best value so far.
  - Explain why searching unsorted data can't beat O(n) in the worst case.
  - Write neighbor loops and initial values that survive empty and one-element arrays.
terms:
  - term: Traversal
    definition: Visiting every element of a sequence once, in order, doing a bounded amount of work for each. With O(1) work per element it's O(n).
  - term: State
    definition: The few variables a traversal carries from one element to the next, like the best value so far and how many times it appeared.
  - term: Loop invariant
    definition: A sentence about the state that's true before every pass. For a traversal it usually reads "after looking at values[0..<i], the state describes those i elements".
  - term: Linear search
    definition: Checking elements one by one until one matches. O(n) in the worst case, and on unsorted data nothing does better.
  - term: Running minimum
    definition: The smallest value seen so far in a traversal. It lets you answer "what's the best earlier partner for this element?" without looking back.
mastery:
  - Write a one-pass function with an explicit state and state its invariant.
  - Turn a nested loop over pairs (i < j) into one pass with a running minimum or maximum, and check it against the nested version.
  - Explain, with the "any skipped position could hold the target" argument, why unsorted search is O(n).
  - Pick a safe initial value (the first element, an optional, or a value that can't win) instead of 0.
  - Loop over adjacent pairs with zip(values, values.dropFirst()) without crashing on empty input.
resources: [swift-array, swift-book-control-flow, swift-book-closures, swift-book-collection-types]
cards:
  - id: m16-l01-c1
    front: What's the invariant of a traversal, in general form?
    back: "\"After looking at values[0..<i], the state describes those i elements.\" For a maximum: best is the largest of the first i values. If it's true before the loop and each pass keeps it true, it's true at the end, for the whole array."
  - id: m16-l01-c2
    front: How do you find the largest prices[j] − prices[i] with i < j in O(n)?
    back: Walk once, carrying the lowest price seen before the current day. At each day, compare today minus that lowest with the best so far, then update the lowest. O(n) time, O(1) extra space, instead of checking all n(n − 1)/2 pairs.
  - id: m16-l01-c3
    front: Why is for i in 1..<values.count risky?
    back: "On an empty array it's 1..<0, and Swift traps: \"Range requires lowerBound <= upperBound\". Use zip(values, values.dropFirst()) or values.indices.dropFirst(), which are simply empty."
  - id: m16-l01-c4
    front: Why can't any algorithm search unsorted data faster than O(n) in the worst case?
    back: If it skips a position, that position could hold the target, and the algorithm would answer wrong. So in the worst case it must look at all n. Sorting or building a Set first only helps if you search many times, and building either one reads all n anyway.
  - id: m16-l01-c5
    front: Why not start a running maximum at 0?
    back: If every value is negative, 0 wins and the answer is a number that isn't in the array. Start with the first element (guard let on first), with an optional, or with a value that can't win, like Int.min.
---

## The idea in one sentence

Many array problems look like they compare every element with every other one, but a single pass solves them if you carry **the right state** from one element to the next.

## The shape of a traversal

Every one-pass solution has the same three parts:

1. **State**: a few variables, set before the loop.
2. **Update**: for each element, adjust the state using only the state and that element.
3. **Answer**: read it from the state after the loop.

The hard part is choosing the state. Ask: "if I'd only seen the first i elements, what would I need to remember to handle element i + 1?" The answer to that question is the state, and the sentence that describes it is the **invariant**.

A leaderboard needs the top score and how many players reached it:

```swift
func topScore(in scores: [Int]) -> (score: Int, count: Int)? {
    guard var best = scores.first else { return nil }
    var count = 0
    for score in scores {
        if score > best {
            best = score
            count = 1
        } else if score == best {
            count += 1
        }
    }
    return (best, count)
}

if let top = topScore(in: [70, 95, 88, 95, 60]) {
    print("top \(top.score), reached \(top.count) times")
}
print(topScore(in: [-4, -9, -4]) ?? (0, 0))
print(topScore(in: []) == nil)
```

```output
top 95, reached 2 times
(score: -4, count: 2)
true
```

Line by line:

1. `guard var best = scores.first` sets the starting maximum to a real element, and returns `nil` for an empty array, where "the top score" doesn't exist. `var` because the loop changes it.
2. `count` starts at 0 because no element has been looked at yet. The first element equals `best`, so the loop's first pass sets `count` to 1.
3. A bigger score replaces the maximum, and the count restarts at 1: the old maximum's count no longer matters.
4. An equal score adds one to the count.
5. The invariant, true before every pass: **after looking at `scores[0..<i]`, `best` is the largest of them and `count` is how many times it appears.** Before the loop, i is 0 and `count` is 0, consistent with "nothing looked at yet". After the loop, i is `scores.count`, and the sentence describes the whole array. That's why the function is correct.

The `-4` case shows why the starting value comes from the array. Start `best` at 0 and an all-negative leaderboard reports a top score of 0 that nobody scored.

Cost: one pass, constant work per element, so **O(n) time** and **O(1) extra space**. You could also write `scores.max()` and then count matches with `filter`. That's two passes, 2n steps, and still O(n): Big O doesn't care how many passes you make, as long as the number of passes doesn't grow with n. Pick whichever reads better. The one-pass version matters when the data can only be read once, like values arriving from a network stream.

### What one pass with a few variables can't do

The pattern needs state of **fixed size**. Maximum, minimum, sum, count, "the first match", "is there any negative" all fit in one or two variables. Some questions don't:

- **The median** needs, in effect, every value you've seen: any of them might turn out to be the middle one.
- **"Has this value appeared before?"** needs a record of everything seen so far. That's a `Set`, O(n) extra space, and it's lesson 5's topic.

When the state you'd need grows with the input, the solution is still one pass, but with O(n) extra space, or it needs sorting first.

## Linear search, and why you can't beat it

Module 15 measured linear search: best case 1, worst case n. Here's the part it didn't prove. **On unsorted data, every correct search is O(n) in the worst case.** Suppose an algorithm answers "not found" without ever reading position 7. Put the target at position 7: the algorithm doesn't know, and answers wrong. So a correct algorithm must, in the worst case, read every position.

Sorting or building a `Set` gets around this only by reading all n elements first. That's why Module 15 framed it as "pay once, search many times".

Searching with a condition instead of a value is the same loop. The standard library has `firstIndex(where:)`, `lastIndex(where:)` and `contains(where:)`, all O(n). Written by hand, as a generic function, the search for the last match walks the indexes backward:

```swift
func lastIndex<Element>(in values: [Element], where matches: (Element) -> Bool) -> Int? {
    for index in values.indices.reversed() where matches(values[index]) {
        return index
    }
    return nil
}

let temperatures = [12, -3, 8, -1, 15, 4]
print(lastIndex(in: temperatures) { $0 < 0 } ?? -1)
print(temperatures.lastIndex { $0 < 0 } ?? -1)
print(lastIndex(in: temperatures) { $0 > 30 } ?? -1)
```

```output
3
3
-1
```

Starting from the end matters for cost, not just for the answer: if what you need is usually near the end (the latest event in a log), a backward search stops sooner. The worst case is still n.

## From pairs to one pass: the running minimum

A price tracker has a product's daily prices. You bought on one day and sold on a later day: what's the biggest gain you could have made? If prices only fell, the answer is 0 (don't buy).

In symbols: the largest `prices[j] - prices[i]` with `i < j`, or 0.

**The naive version** checks every pair. It's the triangle loop from Module 15, n(n − 1)/2 pairs:

```swift
func biggestGainNaive(_ prices: [Int]) -> Int {
    var best = 0
    for buy in prices.indices {
        for sell in (buy + 1)..<prices.count {
            best = max(best, prices[sell] - prices[buy])
        }
    }
    return best
}

print(biggestGainNaive([9, 4, 7, 3, 8, 6]))
print(biggestGainNaive([9, 7, 4]))
```

```output
5
0
```

**O(n²) time, O(1) extra space.** For a year of prices, 365 days, that's 66,430 pairs. For a price history per minute, it's hopeless. (`(buy + 1)..<prices.count` is safe here: `buy` is at most `count - 1`, so the range is at worst empty, never reversed.)

**The pattern version** asks, for each selling day: what's the best day to have bought? The cheapest day before it. You don't need to look back to find it if you carry it with you:

```swift
func biggestGain(_ prices: [Int]) -> Int {
    guard var lowest = prices.first else { return 0 }
    var best = 0
    for price in prices.dropFirst() {
        best = max(best, price - lowest)
        lowest = min(lowest, price)
    }
    return best
}

print(biggestGain([9, 4, 7, 3, 8, 6]))
print(biggestGain([9, 7, 4]))
print(biggestGain([]))
```

```output
5
0
0
```

The invariant: **before handling day j, `lowest` is the cheapest price among days 0 to j − 1, and `best` is the biggest gain from a sale on any of those days.** Each pass computes the gain of selling today with the best possible earlier purchase, then lets today's price join the "earlier days" for tomorrow.

Trace it on `[9, 4, 7, 3, 8, 6]`:

| Day | price | price − lowest | best | lowest after |
| --- | --- | --- | --- | --- |
| 0 | 9 | (start) | 0 | 9 |
| 1 | 4 | −5 | 0 | 4 |
| 2 | 7 | 3 | 3 | 4 |
| 3 | 3 | −1 | 3 | 3 |
| 4 | 8 | 5 | 5 | 3 |
| 5 | 6 | 3 | 5 | 3 |

**O(n) time, O(1) extra space.** The order of the two lines inside the loop encodes `i < j`: the gain uses `lowest` from strictly earlier days, and only then does today's price join. Here, swapping them would still work, because a same-day "gain" is 0 and never beats the floor of 0. In the variant where the answer can be negative ("the smallest loss, if you must trade"), the swap returns 0 for an all-falling list, which is wrong. Keep the order that matches the definition.

Whenever you replace a slow, obviously correct version with a fast, clever one, check them against each other on many inputs:

```swift
func biggestGainNaive(_ prices: [Int]) -> Int {
    var best = 0
    for buy in prices.indices {
        for sell in (buy + 1)..<prices.count {
            best = max(best, prices[sell] - prices[buy])
        }
    }
    return best
}

func biggestGain(_ prices: [Int]) -> Int {
    guard var lowest = prices.first else { return 0 }
    var best = 0
    for price in prices.dropFirst() {
        best = max(best, price - lowest)
        lowest = min(lowest, price)
    }
    return best
}

let series = (0..<300).map { day in (day * 37 + 11) % 101 }
var mismatches = 0
for length in 0...series.count {
    let prefix = Array(series.prefix(length))
    if biggestGain(prefix) != biggestGainNaive(prefix) {
        mismatches += 1
    }
}
print("checked \(series.count + 1) inputs, mismatches: \(mismatches)")
```

```output
checked 301 inputs, mismatches: 0
```

`(day * 37 + 11) % 101` is a cheap way to get a scrambled but repeatable sequence. A real test suite would use random inputs from a generator with a fixed seed, so a failure can be reproduced. Every prefix of the series is tested, including the empty one.

## Comparing neighbors

Some questions are about consecutive elements: "on how many days did the price go up?" The tempting loop is `for i in 1..<prices.count`. It works until the array is empty:

```swift runtime-error Range requires lowerBound <= upperBound
let prices: [Int] = []
var rises = 0
for i in 1..<prices.count where prices[i] > prices[i - 1] {
    rises += 1
}
print(rises)
```

`1..<0` is a range whose start is after its end, and Swift traps when you create it. Two loops that can't crash:

```swift
let prices = [9, 4, 7, 3, 8, 6]

var rises = 0
for (yesterday, today) in zip(prices, prices.dropFirst()) where today > yesterday {
    rises += 1
}
print(rises)

var risingDays: [Int] = []
for day in prices.indices.dropFirst() where prices[day] > prices[day - 1] {
    risingDays.append(day)
}
print(risingDays)

let empty: [Int] = []
print(zip(empty, empty.dropFirst()).count { pair in pair.1 > pair.0 })
```

```output
2
[2, 4]
0
```

`zip(prices, prices.dropFirst())` pairs each element with the next one and stops when the shorter side runs out, so an array of n elements gives n − 1 pairs, and an empty or one-element array gives none. `prices.indices.dropFirst()` is the range of indexes without the first, which is empty for an empty array instead of reversed. Use `zip` when you only need the values and `indices.dropFirst()` when you need the position. The last line uses `count(where:)`, which counts the elements that satisfy a condition (Swift 6.0 and later).

## A practical example: the longest streak

A habit tracker stores minutes practiced per day. The goal is 20 minutes, and the app shows the longest run of consecutive days that met it.

State: the length of the current run, and the longest so far. Invariant: after day i, `current` is the length of the run that ends at day i (0 if day i missed the goal) and `longest` is the longest run among days 0 to i.

```swift
func longestStreak(_ minutes: [Int], goal: Int) -> Int {
    var current = 0
    var longest = 0
    for dayMinutes in minutes {
        if dayMinutes >= goal {
            current += 1
            longest = max(longest, current)
        } else {
            current = 0
        }
    }
    return longest
}

let log = [25, 30, 5, 20, 22, 40, 0, 21, 35, 50, 20]
print(longestStreak(log, goal: 20))
print(longestStreak([10, 5], goal: 20))
print(longestStreak([], goal: 20))
```

```output
4
0
0
```

The last four days (21, 35, 50, 20) form a run of 4, and the run in the middle (20, 22, 40) is 3. Updating `longest` on every successful day, not when a run breaks, matters here: this log **ends** in the middle of its longest run, and there's no miss after it to trigger an update. O(n) time, O(1) extra space.

## Common mistakes

> [!error] Starting the maximum at 0
> `var highest = 0` returns 0 for `[-4, -9, -2]`, a value that isn't in the array. Start from `values.first` with `guard let`, or return an optional, or use a starting value that can't win, like `Int.min` for a maximum. The same goes for minimums: `var lowest = 0` is wrong for any list of positive numbers.

> [!error] Range requires lowerBound <= upperBound
> `for i in 1..<values.count` crashes when `values` is empty. Use `zip(values, values.dropFirst())` or `values.indices.dropFirst()`, or check `values.count >= 2` first.

> [!error] Updating the answer only when a run ends
> If the best run is the last one, nothing ends it, and its length is never recorded. Update the answer on every step, or do one last update after the loop.

> [!error] Sorting to find a maximum or minimum
> `values.sorted().last` is O(n log n) and allocates a new array. `values.max()` is one pass, O(n), with no extra array.

> [!warning] Merging passes for no reason
> Two simple passes (`max()`, then a `filter`) are O(n) just like one clever pass. Squeeze passes together when the data can only be read once or a profile tells you to, not by default.

## Exercises

````exercise
id: m16-l01-e1
type: comprehension
prompt: Which of these can't be computed in one pass that keeps only a fixed number of variables, however many elements there are?
choices:
  - text: The median of the values
    correct: true
    why: Until the end, any value seen so far might be the middle one, so you'd have to remember all of them. That's O(n) state.
  - text: The index of the first negative value
    correct: false
    why: One variable for the answer, and you can stop at the first match.
  - text: The average of the values
    correct: false
    why: A running sum and a count are enough. Divide at the end.
  - text: The largest value and the second largest value
    correct: false
    why: Two variables. Each new value either replaces the largest (and the old largest becomes second), replaces the second, or changes nothing.
solution: |
  **The median.** A traversal with fixed-size state works when each element can update a summary that has already forgotten the individual elements. The average keeps a sum and a count; the top two keep two numbers; the first negative keeps one index. The median depends on the ordering of all the values, and until the last element arrives you can't rule any of them out. You need the values themselves: sort them (O(n log n)) or use a selection algorithm, with O(n) extra space either way.
````

````exercise
id: m16-l01-e2
type: prediction
prompt: Predict the exact output.
code: |
  let steps = [8_000, 12_000, 11_000, 15_000, 9_000, 16_000]
  var record = 0
  var newRecords = 0
  for (day, count) in steps.enumerated() where count > record {
      record = count
      newRecords += 1
      print("day \(day): \(count)")
  }
  print("records: \(newRecords)")
output: |
  day 0: 8000
  day 1: 12000
  day 3: 15000
  day 5: 16000
  records: 4
hints:
  - The where clause runs the body only when the count beats the record so far.
  - 11,000 and 9,000 don't beat the record at their point in the list.
solution: |
  ```output
  day 0: 8000
  day 1: 12000
  day 3: 15000
  day 5: 16000
  records: 4
  ```

  `record` is the running maximum, starting at 0, which works here because step counts can't be negative. A day prints only if it beats every earlier day: 8,000 beats 0, 12,000 beats 8,000, 11,000 doesn't, 15,000 does, 9,000 doesn't, 16,000 does. Integers print without the `_` separators you can write in literals.
````

````exercise
id: m16-l01-e3
type: find-errors
prompt: This function should return the coldest temperature and the number of days the temperature dropped compared with the day before. Which statements are true?
code: |
  func coldestAndDrops(_ temperatures: [Int]) -> (coldest: Int, drops: Int) {
      var coldest = 0
      var drops = 0
      for i in 1..<temperatures.count {
          if temperatures[i] < temperatures[i - 1] {
              drops += 1
          }
          coldest = min(coldest, temperatures[i])
      }
      return (coldest, drops)
  }
choices:
  - text: "For [5, 8, 3, 6] it reports a coldest temperature of 0."
    correct: true
    why: coldest starts at 0 and every temperature is above 0, so min never changes it.
  - text: "It crashes on an empty array."
    correct: true
    why: "1..<0 traps with \"Range requires lowerBound <= upperBound\"."
  - text: "It never looks at temperatures[0] when computing the minimum."
    correct: true
    why: "The loop starts at 1. For [-7, 2, 4], even with a correct starting value, -7 would be missed."
  - text: "It counts drops wrong: it should compare with temperatures[i + 1]."
    correct: false
    why: "Comparing day i with day i − 1 is exactly \"dropped compared with the day before\". With i + 1 it would also run past the end."
  - text: "It's O(n²) because of the min call inside the loop."
    correct: false
    why: min of two values is O(1). The function is one pass, O(n).
rubric:
  - I found the wrong starting value for the minimum.
  - I found the crash on an empty array.
  - I noticed that the first temperature is never considered for the minimum.
  - I wrote a version that returns an optional (or handles empty input) and tested it.
solution: |
  Three real bugs: the minimum starts at 0 instead of a real temperature, the loop skips index 0 for the minimum, and `1..<temperatures.count` crashes on an empty array. Returning an optional handles "no temperatures" honestly, and `zip` handles the neighbor comparison without a range:

  ```swift
  func coldestAndDrops(_ temperatures: [Int]) -> (coldest: Int, drops: Int)? {
      guard var coldest = temperatures.first else { return nil }
      var drops = 0
      for (yesterday, today) in zip(temperatures, temperatures.dropFirst()) {
          if today < yesterday {
              drops += 1
          }
          coldest = min(coldest, today)
      }
      return (coldest, drops)
  }

  print(coldestAndDrops([5, 8, 3, 6]).map { "\($0.coldest) \($0.drops)" } ?? "none")
  print(coldestAndDrops([-7, 2, 4]).map { "\($0.coldest) \($0.drops)" } ?? "none")
  print(coldestAndDrops([]).map { "\($0.coldest) \($0.drops)" } ?? "none")
  ```

  ```output
  3 1
  -7 0
  none
  ```

  `coldest` starts at the first temperature, so the loop only has to consider the rest, and every `today` is exactly one of those. `Optional.map` (Module 8) formats the tuple when there is one.
````

````exercise
id: m16-l01-e4
type: fill-in
prompt: "Complete the one-pass version of \"biggest drop\": the largest prices[i] − prices[j] with i < j, or 0. It should print `6 0`."
code: |
  func biggestDrop(_ prices: [Int]) -> Int {
      guard var highest = prices.first else { return 0 }
      var best = 0
      for price in prices.[[1]]() {
          best = max(best, [[2]])
          highest = [[3]](highest, price)
      }
      return best
  }

  print(biggestDrop([4, 9, 5, 3, 7]), biggestDrop([1, 2, 3]))
blanks:
  - id: "1"
    answers: ["dropFirst"]
  - id: "2"
    answers: ["highest - price", "highest-price"]
  - id: "3"
    answers: ["max"]
solution: |
  ```swift
  func biggestDrop(_ prices: [Int]) -> Int {
      guard var highest = prices.first else { return 0 }
      var best = 0
      for price in prices.dropFirst() {
          best = max(best, highest - price)
          highest = max(highest, price)
      }
      return best
  }

  print(biggestDrop([4, 9, 5, 3, 7]), biggestDrop([1, 2, 3]))
  ```

  ```output
  6 0
  ```

  It's the mirror image of the running minimum: for each day, the worst earlier day to have bought is the most expensive one, so carry the running **maximum**. The biggest drop in `[4, 9, 5, 3, 7]` is 9 → 3. For a rising list, every drop is negative and the floor of 0 wins. O(n) time, O(1) extra space.
````

````exercise
id: m16-l01-e5
type: solve
prompt: |
  A fitness app marks a day as a "comeback" when it's higher than the day before **and** the day before was lower than the day before that (a dip followed by a rise). Write `func comebackDays(_ steps: [Int]) -> [Int]` that returns the indexes of all comeback days, in one pass, without crashing on short arrays.

  Expected:

  ```output
  [2, 5]
  []
  []
  ```

  for `[9, 4, 7, 8, 3, 6]`, `[1, 2]` and `[]`.
starter: |
  func comebackDays(_ steps: [Int]) -> [Int] {
      var result: [Int] = []
      // One pass over the days that have two days before them
      return result
  }

  print(comebackDays([9, 4, 7, 8, 3, 6]))
  print(comebackDays([1, 2]))
  print(comebackDays([]))
hints:
  - Day i needs days i − 1 and i − 2, so i starts at 2.
  - "steps.indices.dropFirst(2) is empty when there are fewer than three days, so it can't crash."
rubric:
  - The loop starts at index 2 without building a reversed range.
  - Both conditions (a dip, then a rise) are checked.
  - It returns [] for arrays with fewer than three elements.
  - I stated the complexity, O(n) time and O(k) for the k indexes returned.
solution: |
  ```swift
  func comebackDays(_ steps: [Int]) -> [Int] {
      var result: [Int] = []
      for day in steps.indices.dropFirst(2) {
          let dipped = steps[day - 1] < steps[day - 2]
          let rose = steps[day] > steps[day - 1]
          if dipped && rose {
              result.append(day)
          }
      }
      return result
  }

  print(comebackDays([9, 4, 7, 8, 3, 6]))
  print(comebackDays([1, 2]))
  print(comebackDays([]))
  ```

  ```output
  [2, 5]
  []
  []
  ```

  Day 2 (7) follows a dip from 9 to 4. Day 3 (8) rises, but the day before it didn't dip. Day 5 (6) follows a dip from 8 to 3. `indices.dropFirst(2)` skips the first two indexes and is simply empty for short arrays, so `steps[day - 2]` is always valid. One pass with O(1) work per day: **O(n) time**. The result can hold up to about n / 2 indexes, so the extra space is O(k) for the k comeback days, O(1) besides the output.
````

````exercise
id: m16-l01-e6
type: refactor
prompt: |
  This function finds the largest temperature range between an earlier reading and a later, warmer one, by checking every pair. Rewrite it as one pass, with the same output, and state the time and extra space of both versions.
code: |
  func largestWarming(_ readings: [Int]) -> Int {
      var best = 0
      for i in readings.indices {
          for j in readings.indices where j > i {
              if readings[j] - readings[i] > best {
                  best = readings[j] - readings[i]
              }
          }
      }
      return best
  }

  print(largestWarming([14, 11, 17, 9, 15, 19, 12]))
  print(largestWarming([5]))
rubric:
  - The rewrite carries the coldest earlier reading instead of looping back.
  - It computes the warming before adding the current reading to the coldest-so-far.
  - It gives the same output, including for one element.
  - "I stated O(n²) time and O(1) space for the original (the inner loop visits all n indexes for each i, even with the where clause), and O(n) time and O(1) space for the rewrite."
solution: |
  ```swift
  func largestWarming(_ readings: [Int]) -> Int {
      guard var coldest = readings.first else { return 0 }
      var best = 0
      for reading in readings.dropFirst() {
          best = max(best, reading - coldest)
          coldest = min(coldest, reading)
      }
      return best
  }

  print(largestWarming([14, 11, 17, 9, 15, 19, 12]))
  print(largestWarming([5]))
  ```

  ```output
  10
  0
  ```

  It's the running minimum from the lesson: the best partner for each reading is the coldest one before it. 9 then 19 gives 10.

  The original is worse than it looks. The `where j > i` filter skips the body, but the inner loop still walks **all** n indexes for every i: n² iterations, not n(n − 1)/2. Either way it's **O(n²) time**, O(1) extra space. The rewrite is **O(n) time**, O(1) extra space. For a week of hourly readings (168), that's 28,224 inner iterations against 167.
````

## Summary

- A traversal has three parts: **state** set before the loop, an **update** per element, and the **answer** read from the state. Choose the state by asking what you'd need to remember about the first i elements.
- The **invariant** ("after `values[0..<i]`, the state describes them") is what makes a one-pass solution correct, and writing it down is how you find bugs in it.
- One pass with fixed-size state can't answer everything: the median and "seen before?" need O(n) state.
- On unsorted data, every correct search is **O(n)** in the worst case: any skipped position could hold the target.
- A question about pairs `i < j` often reduces to one pass carrying the best earlier partner: a **running minimum** or maximum. O(n²) becomes O(n), with O(1) extra space. Check the fast version against the naive one on many inputs.
- Start maximums and minimums from a real element, not 0. Loop over neighbors with `zip(values, values.dropFirst())` or `indices.dropFirst()`, never `1..<values.count`. Record the best run on every step, not only when a run ends.
