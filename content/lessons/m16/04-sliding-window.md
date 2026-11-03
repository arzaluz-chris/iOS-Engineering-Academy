---
id: m16-l04
title: Sliding window
description: You keep a running summary of a contiguous range as it slides along an array or string, adding what enters and removing what leaves; solve fixed-size windows in O(n) instead of O(n·k); grow and shrink variable windows for "longest" and "shortest" questions; and learn why negative numbers break the variable window.
module: m16
order: 4
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m16-l03]
objectives:
  - Recognize window problems from words like contiguous, consecutive, substring and subarray.
  - Slide a fixed-size window in O(n) by adding the entering element and removing the leaving one.
  - Write the variable window for "longest valid" and "shortest valid" and explain why it's O(n).
  - Keep window state in a sum, a Set or a dictionary of counts.
  - Explain why the variable window needs a condition that can only get worse as the window grows.
terms:
  - term: Window
    definition: A contiguous range of a sequence, values[left...right], described by its two ends.
  - term: Fixed-size window
    definition: A window of exactly k elements that moves one position at a time. One element enters at the right and one leaves at the left.
  - term: Variable-size window
    definition: A window whose right end advances every step and whose left end advances only as far as needed to keep (or reach) a condition.
  - term: Window state
    definition: A summary of the window's contents that can be updated in O(1) when one element enters or leaves, like a sum or a dictionary of counts.
  - term: Amortized O(n)
    definition: "Here: the inner while loop can run many times in one pass, but left only moves forward and never past the end, so across the whole run it moves at most n times."
mastery:
  - Turn an O(n·k) recomputation of every window into an O(n) slide, and handle k larger than the array.
  - Write the longest-valid-window loop (expand, shrink while invalid, record) and the shortest-valid-window loop (expand, record and shrink while valid).
  - "Use a Set or a [Character: Int] dictionary as window state for strings, after converting the string to an array."
  - Compute a window's length as right − left + 1 and check it on a one-element window.
  - Recognize when a window doesn't apply (negative values with a sum condition) and name prefix sums as the alternative.
resources: [swift-array, swift-set, swift-dictionary, swift-book-strings, swift-book-control-flow]
cards:
  - id: m16-l04-c1
    front: How do you get the sum of every window of k consecutive values in O(n)?
    back: Keep a running sum. Add the element that enters at the right, subtract the one that leaves at the left (values[right − k]). Each step is O(1) instead of re-adding k values.
  - id: m16-l04-c2
    front: What's the loop for "the longest window that satisfies a condition"?
    back: For each right, add values[right]. While the window is invalid, remove values[left] and move left. Then the window is the longest valid one ending at right; record right − left + 1.
  - id: m16-l04-c3
    front: Why is the variable window O(n) even with a while inside a for?
    back: left only moves forward and never passes the end, so the inner loop runs at most n times in total over the whole run, not n times per step. Total work is O(n).
  - id: m16-l04-c4
    front: Why does the sum-based variable window fail with negative numbers?
    back: It assumes that shrinking a window makes its sum smaller and growing it makes it bigger. With negatives, adding an element can lower the sum, so a window you dropped could become valid again. Use prefix sums with a dictionary for "sum exactly k" (lesson 6), or brute force for small inputs.
  - id: m16-l04-c5
    front: How do you run a window over a String?
    back: "Convert it first: let characters = Array(text). Strings can't be subscripted with Int, so indexes like characters[left] need the array. The conversion is O(n) time and space."
---

## The idea in one sentence

When a problem asks about **contiguous** stretches of a sequence, don't recompute each stretch from scratch: slide a window along, update its summary with what enters and what leaves, and the whole scan is **O(n)**.

## When to think "window"

The giveaway words: **contiguous, consecutive, subarray, substring, in a row, stretch**. "The best 7 consecutive days", "the longest substring without…", "the shortest run of songs that lasts at least an hour". If the question allowed picking elements from anywhere (a *subset*, not a *subarray*), it wouldn't be a window problem.

The second check: **can you update the answer for a window in O(1) when one element joins or leaves?** A sum can (add, subtract). A count of each character can (increment, decrement). A maximum can't, directly: when the maximum leaves, you don't know the next one. That case needs a monotonic queue, which Module 17 covers.

## Fixed-size windows

A fitness app shows a user's best 7-day step total. Daily steps are in an array.

**Naive version**: for every starting day, add the next k days.

```swift
func bestTotalNaive(_ values: [Int], windowSize k: Int) -> (best: Int, additions: Int)? {
    guard k > 0, k <= values.count else { return nil }
    var best = Int.min
    var additions = 0
    for start in 0...(values.count - k) {
        var total = 0
        for offset in 0..<k {
            total += values[start + offset]
            additions += 1
        }
        best = max(best, total)
    }
    return (best, additions)
}

let year = (0..<365).map { day in 6_000 + (day * 7_919) % 5_000 }
if let result = bestTotalNaive(year, windowSize: 30) {
    print("best: \(result.best), additions: \(result.additions)")
}
```

```output
best: 262695, additions: 10080
```

There are n − k + 1 windows and each costs k additions: (n − k + 1) · k. For a year and a 30-day window, 10,080 additions, and **O(n · k)** in general. With k close to n / 2 it's quadratic.

**The pattern**: neighboring windows share all but two elements. Moving the window one step right adds `values[right]` and drops `values[right - k]`:

```swift
func bestTotal(_ values: [Int], windowSize k: Int) -> Int? {
    guard k > 0, k <= values.count else { return nil }
    var windowSum = 0
    var best = Int.min
    for right in values.indices {
        windowSum += values[right]
        if right >= k {
            windowSum -= values[right - k]
        }
        if right >= k - 1 {
            best = max(best, windowSum)
        }
    }
    return best
}

let year = (0..<365).map { day in 6_000 + (day * 7_919) % 5_000 }
print(bestTotal(year, windowSize: 30) ?? -1)
print(bestTotal([4, 2, 12, 3, 8], windowSize: 2) ?? -1)
print(bestTotal([4, 2], windowSize: 3) ?? -1)
```

```output
262695
15
-1
```

Line by line:

1. The `guard` rejects windows that can't exist. Without it, a k larger than the array would return `Int.min`, a number that looks like an answer.
2. `windowSum += values[right]`: the new element enters.
3. `if right >= k`: the window now has k + 1 elements, so the one at `right - k` leaves. For the first k elements nothing leaves; the window is still filling.
4. `if right >= k - 1`: from here on, the window has exactly k elements, and its sum is a candidate. Before that, it's a partial window and doesn't count.

The invariant: **after handling `right`, `windowSum` is the sum of `values[max(0, right - k + 1)...right]`**, the last k elements (or fewer while filling). Each step is O(1): **O(n) time, O(1) extra space**, 365 additions and 335 subtractions for the year instead of 10,080 additions.

## Variable-size windows: the longest valid window

A music app builds a commute playlist: the longest run of **consecutive** tracks from a queue that fits in the commute. Durations are in minutes, and none is negative.

**Naive version**: try every start, extend while the total fits, and keep the longest. With a running sum per start, that's O(n²).

**The pattern**: let the right end advance one track at a time. When the window gets too long (total over budget), drop tracks from the left until it fits again. After that, the window is the longest valid one that **ends at `right`**, and the best of those is the answer.

```swift
func longestRun(_ durations: [Int], budget: Int) -> Int {
    var left = 0
    var total = 0
    var longest = 0
    for right in durations.indices {
        total += durations[right]
        while total > budget {
            total -= durations[left]
            left += 1
        }
        longest = max(longest, right - left + 1)
    }
    return longest
}

let queue = [4, 3, 7, 2, 1, 5, 9, 2]
print(longestRun(queue, budget: 15))
print(longestRun(queue, budget: 1))
print(longestRun([], budget: 10))
```

```output
4
1
0
```

Trace for budget 15:

| right | track | total after adding | shrink | window | length | longest |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 4 | 4 | | [4] | 1 | 1 |
| 1 | 3 | 7 | | [4, 3] | 2 | 2 |
| 2 | 7 | 14 | | [4, 3, 7] | 3 | 3 |
| 3 | 2 | 16 | drop 4 → 12 | [3, 7, 2] | 3 | 3 |
| 4 | 1 | 13 | | [3, 7, 2, 1] | 4 | 4 |
| 5 | 5 | 18 | drop 3 → 15 | [7, 2, 1, 5] | 4 | 4 |
| 6 | 9 | 24 | drop 7, 2 → 15 | [1, 5, 9] | 3 | 4 |
| 7 | 2 | 17 | drop 1, 5 → 11 | [9, 2] | 2 | 4 |

Three things to notice:

- **`while`, not `if`.** At `right = 6`, two tracks have to leave before the window fits. An `if` would drop one and record an invalid window.
- **Record after shrinking.** The window is only guaranteed valid once the `while` ends.
- **`right - left + 1`** is the length of `left...right`, both ends included. A one-element window has `left == right` and length 1. For budget 1, only the track of 1 minute fits, and the `while` can even empty the window completely (`left == right + 1`, length 0) when a single track is over budget.

**Why it's O(n)**: the `for` runs n times. The `while` looks like it could run n times per step, but `left` only moves forward and never past `right + 1`, so over the **entire** run it moves at most n times. Total work: at most 2n window updates. **O(n) time, O(1) extra space.** This is an amortized argument, like `append` in Module 15: some steps are expensive, but the total is bounded.

**Why it's correct**: `left` only moved past a position p because, at some earlier step r′, the window from p to r′ was over budget. With no negative durations, the window from p to the current `right` contains that one and can only be longer in total, so it's over budget too. So no valid window ending at `right` starts before `left`, and the longest valid window ending at `right` starts exactly at `left`.

### Window state that isn't a sum

The window's state can be anything you can update in O(1) when an element enters or leaves. For "the longest stretch of a string with no repeated character", it's the set of characters in the window:

```swift
func longestWithoutRepeats(_ text: String) -> Int {
    let characters = Array(text)
    var inWindow = Set<Character>()
    var left = 0
    var longest = 0
    for right in characters.indices {
        while inWindow.contains(characters[right]) {
            inWindow.remove(characters[left])
            left += 1
        }
        inWindow.insert(characters[right])
        longest = max(longest, right - left + 1)
    }
    return longest
}

print(longestWithoutRepeats("abcabcbb"))
print(longestWithoutRepeats("swiftui"))
print(longestWithoutRepeats(""))
```

```output
3
6
0
```

Here the shrink happens **before** the new character joins: while it's already in the window, drop characters from the left, which removes the earlier copy and everything before it. Then add it. In "swiftui", the window grows to "swiftu", the second "i" forces the left end past the first "i" ("ftui" is left after adding it), and the longest stays 6.

`Array(text)` converts the string to `[Character]` first, O(n) time and space. Strings can't be subscripted with integers:

```swift no-compile cannot subscript String with an Int
let text = "swiftui"
let third = text[2]
print(third)
```

Set operations are O(1) on average, so this is **O(n) time on average**. The extra space is O(n) for the character array, plus a set that never holds more than the number of distinct characters in the text.

## Variable-size windows: the shortest valid window

The opposite question: the **shortest** run of tracks that lasts **at least** `minimum` minutes, for a workout. Now the window is valid when it's big enough, so the loop flips: grow until valid, then shrink **while it stays valid**, recording at each step.

```swift
func shortestRun(_ durations: [Int], atLeast minimum: Int) -> Int? {
    var left = 0
    var total = 0
    var shortest: Int?
    for right in durations.indices {
        total += durations[right]
        while total >= minimum {
            shortest = min(shortest ?? Int.max, right - left + 1)
            total -= durations[left]
            left += 1
        }
    }
    return shortest
}

let queue = [4, 3, 7, 2, 1, 5, 9, 2]
print(shortestRun(queue, atLeast: 14) ?? -1)
print(shortestRun(queue, atLeast: 9) ?? -1)
print(shortestRun(queue, atLeast: 100) ?? -1)
```

```output
2
1
-1
```

The difference from the longest version is **where you record**: inside the `while`, before each shrink, because every window the `while` sees is valid and each one is shorter than the last. When no window ever reaches the minimum, `shortest` stays `nil`. Same cost: **O(n) time, O(1) extra space**, because `left` still only moves forward.

| Question | Shrink while | Record |
| --- | --- | --- |
| Longest window that's valid | the window is **invalid** | after the `while` |
| Shortest window that's valid | the window is **valid** | inside the `while`, before shrinking |


## When the window breaks: negative numbers

Both variable windows rely on one assumption: **adding an element makes the sum bigger, and removing one makes it smaller.** That's what lets `left` move forward and never come back. With negative values, it's false. Take "the longest stretch of daily balance changes whose total is at most 0", using the same `longestRun`:

```swift
func longestRun(_ durations: [Int], budget: Int) -> Int {
    var left = 0
    var total = 0
    var longest = 0
    for right in durations.indices {
        total += durations[right]
        while total > budget {
            total -= durations[left]
            left += 1
        }
        longest = max(longest, right - left + 1)
    }
    return longest
}

let changes = [3, -5, 1]
print("window: \(longestRun(changes, budget: 0))")

var bruteForce = 0
for start in changes.indices {
    var total = 0
    for end in start..<changes.count {
        total += changes[end]
        if total <= 0 {
            bruteForce = max(bruteForce, end - start + 1)
        }
    }
}
print("brute force: \(bruteForce)")
```

```output
window: 2
brute force: 3
```

At `right = 0`, the window `[3]` is over budget, so the loop drops the 3 and moves `left` past it for good. But the whole array, 3 − 5 + 1 = −1, is within budget: a later negative value made a window that starts at 0 valid again. The window can't go back for it.

So before using a variable window with a sum, check that the values can't be negative (durations, sizes, counts and prices usually can't). If they can, switch tools. **Prefix sums** with a dictionary (lesson 6) solve the "sum exactly k" versions in O(n) regardless of signs. The "at most" versions with negatives need more machinery, and for small inputs the O(n²) brute force is a fine answer.

## Common mistakes

> [!error] Shrinking with if instead of while
> One new element can make the window invalid by more than one element's worth. An `if` drops one and records a window that still breaks the condition.

> [!error] Recording in the wrong place
> For "longest valid", record **after** the shrinking loop, when the window is valid again. For "shortest valid", record **inside** it, before each shrink. Recording before shrinking in the "longest" version counts invalid windows.

> [!error] right − left instead of right − left + 1
> `left...right` includes both ends. Check the formula on a one-element window: `left == right` must give 1.

> [!error] A fixed window larger than the array
> With k > count, there's no window at all. Without a guard, the code either returns its starting value (like `Int.min`) as if it were an answer, or the naive version's `0...(count - k)` builds a reversed range and traps.

> [!error] Using a sum window with negative values
> The window moves `left` forward on the assumption that the dropped elements can never be part of a valid window again. Negatives break that, silently. Use prefix sums (lesson 6) for "exactly k", or the brute force for small inputs.

## Exercises

````exercise
id: m16-l04-e1
type: comprehension
prompt: Which of these is a sliding window problem?
choices:
  - text: "The longest stretch of consecutive days on which the user's mood score never dropped below 3"
    correct: true
    why: "\"Consecutive\" means contiguous, and the condition only gets worse as the stretch grows: one bad day breaks it."
  - text: "The largest total from any 5 transactions, not necessarily consecutive"
    correct: false
    why: "Any 5, from anywhere, is a subset, not a window. Pick the 5 largest instead."
  - text: The number of distinct values in the whole array
    correct: false
    why: That's one Set built over the whole array. There's no stretch to slide.
  - text: Whether the array is sorted
    correct: false
    why: That's a neighbor comparison over the whole array (lesson 1), not a window.
solution: |
  **The mood stretch.** The two signals are "consecutive" and a condition that, once broken, stays broken while the window still contains the offending day: a variable window that grows while every day is at least 3, and restarts after a bad day. (The simpler one-pass streak from lesson 1 also solves this one; a window is the general form, for conditions like "at most one bad day".) "Any 5 transactions" doesn't care about adjacency, so a window would miss the best choice.
````

````exercise
id: m16-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  let visits = [3, 1, 4, 1, 5, 9]
  let k = 3
  var windowSum = 0
  for right in visits.indices {
      windowSum += visits[right]
      if right >= k {
          windowSum -= visits[right - k]
      }
      if right >= k - 1 {
          print("\(right - k + 1)...\(right): \(windowSum)")
      }
  }
output: |
  0...2: 8
  1...3: 6
  2...4: 10
  3...5: 15
hints:
  - Nothing prints until the window has k elements, at right = 2.
  - From right = 3 on, each step adds one value and subtracts the one k positions back.
solution: |
  ```output
  0...2: 8
  1...3: 6
  2...4: 10
  3...5: 15
  ```

  The first window, indexes 0 to 2, is 3 + 1 + 4 = 8. Then each step adds the new element and subtracts the one that left: 8 + 1 − 3 = 6, 6 + 5 − 1 = 10, 10 + 9 − 4 = 15. Six elements and a window of 3 give 6 − 3 + 1 = 4 windows. The interpolation prints the window's index range; it's text, not a Swift range.
````

````exercise
id: m16-l04-e3
type: find-errors
prompt: "This function should return the length of the longest stretch of consecutive file sizes whose total is at most `limit` (sizes are never negative). Which statements are true?"
code: |
  func longestBatch(_ sizes: [Int], limit: Int) -> Int {
      var left = 0
      var total = 0
      var longest = 0
      for right in sizes.indices {
          total += sizes[right]
          if total > limit {
              total -= sizes[left]
              left += 1
          }
          longest = max(longest, right - left)
      }
      return longest
  }
choices:
  - text: "The length is off by one: a window from left to right has right − left + 1 elements."
    correct: true
    why: "For a one-element window, left == right and the function counts 0."
  - text: "The if should be a while: one large file can require dropping several files from the left."
    correct: true
    why: "With sizes [1, 1, 1, 9] and limit 9, adding 9 needs three files dropped, and the if drops one, leaving an over-limit window that gets recorded."
  - text: "It's O(n²) because left can move up to n times."
    correct: false
    why: left moves at most n times in total over the whole run, so even with a while the function is O(n).
  - text: "It crashes when sizes is empty."
    correct: false
    why: The for loop over an empty range doesn't run, and the function returns 0.
rubric:
  - I found the off-by-one in the length.
  - I found that if must be while, and gave an input that shows it.
  - I explained why the corrected version is still O(n).
  - I tested the fix, including a single file over the limit.
solution: |
  Two bugs that partly hide each other. The length should be `right - left + 1`. And the shrink must be a `while`: after adding a big file, the window may still be over the limit after dropping one file. Fixed:

  ```swift
  func longestBatch(_ sizes: [Int], limit: Int) -> Int {
      var left = 0
      var total = 0
      var longest = 0
      for right in sizes.indices {
          total += sizes[right]
          while total > limit {
              total -= sizes[left]
              left += 1
          }
          longest = max(longest, right - left + 1)
      }
      return longest
  }

  print(longestBatch([1, 1, 1, 9], limit: 9))
  print(longestBatch([2, 3, 1, 2], limit: 6))
  print(longestBatch([10], limit: 5))
  print(longestBatch([], limit: 5))
  ```

  ```output
  3
  3
  0
  0
  ```

  For `[10]` with limit 5, the `while` drops the only file, leaving `left = 1, right = 0`: an empty window of length 0, which is correct. `left` moves forward at most n times across the whole run, so the corrected function is O(n) time and O(1) extra space.
````

````exercise
id: m16-l04-e4
type: fill-in
prompt: Complete this function. It counts how many windows of `k` consecutive hours had more than `threshold` errors in total. It should print `3 0`.
code: |
  func busyWindows(_ errors: [Int], k: Int, threshold: Int) -> Int {
      guard k > 0, k <= errors.count else { return 0 }
      var windowSum = 0
      var count = 0
      for right in errors.indices {
          windowSum += errors[right]
          if right >= k {
              windowSum -= errors[[[1]]]
          }
          if right >= [[2]] && windowSum > threshold {
              count += 1
          }
      }
      return count
  }

  let hourly = [0, 4, 1, 0, 6, 2, 0]
  print(busyWindows(hourly, k: 3, threshold: 6), busyWindows(hourly, k: 10, threshold: 0))
blanks:
  - id: "1"
    answers: ["right - k", "right-k"]
  - id: "2"
    answers: ["k - 1", "k-1"]
solution: |
  ```swift
  func busyWindows(_ errors: [Int], k: Int, threshold: Int) -> Int {
      guard k > 0, k <= errors.count else { return 0 }
      var windowSum = 0
      var count = 0
      for right in errors.indices {
          windowSum += errors[right]
          if right >= k {
              windowSum -= errors[right - k]
          }
          if right >= k - 1 && windowSum > threshold {
              count += 1
          }
      }
      return count
  }

  let hourly = [0, 4, 1, 0, 6, 2, 0]
  print(busyWindows(hourly, k: 3, threshold: 6), busyWindows(hourly, k: 10, threshold: 0))
  ```

  ```output
  3 0
  ```

  The windows of 3 hours sum to 5, 5, 7, 8 and 8, and three of them are over 6. The element that leaves when `right` reaches `k` is the one k positions back, `right - k`; a window is complete once `right` reaches `k - 1`. With `k = 10`, longer than the 7 hours, the `guard` returns 0: there's no window of 10 hours to count. O(n) time, O(1) extra space.
````

````exercise
id: m16-l04-e5
type: solve
prompt: |
  A radio app plays a queue of tracks, each tagged with a genre. Write `func longestTwoGenreRun(_ genres: [String]) -> Int` that returns the length of the longest stretch of consecutive tracks that uses **at most two different genres**. Keep a `[String: Int]` of how many tracks of each genre are in the window, and make it O(n) on average.

  Expected output for the starter's calls:

  ```output
  4
  3
  0
  ```
starter: |
  func longestTwoGenreRun(_ genres: [String]) -> Int {
      var counts: [String: Int] = [:]
      var left = 0
      var longest = 0
      // Expand right, shrink while the window has more than two genres
      return longest
  }

  print(longestTwoGenreRun(["pop", "rock", "pop", "rock", "jazz", "jazz"]))
  print(longestTwoGenreRun(["pop", "rock", "jazz", "pop", "jazz"]))
  print(longestTwoGenreRun([]))
hints:
  - "The number of different genres in the window is counts.count, as long as genres whose count drops to 0 are removed from the dictionary."
  - "When a count reaches 0, set counts[genre] = nil."
rubric:
  - Uses the "longest valid" loop, shrinking while counts.count > 2.
  - Removes a genre from the dictionary when its count reaches 0.
  - Records right − left + 1 after shrinking.
  - "States O(n) time on average (dictionary operations are O(1) on average) and O(1) extra space for the dictionary, which never holds more than 3 keys."
solution: |
  ```swift
  func longestTwoGenreRun(_ genres: [String]) -> Int {
      var counts: [String: Int] = [:]
      var left = 0
      var longest = 0
      for right in genres.indices {
          counts[genres[right], default: 0] += 1
          while counts.count > 2 {
              let leaving = genres[left]
              counts[leaving, default: 0] -= 1
              if counts[leaving] == 0 {
                  counts[leaving] = nil
              }
              left += 1
          }
          longest = max(longest, right - left + 1)
      }
      return longest
  }

  print(longestTwoGenreRun(["pop", "rock", "pop", "rock", "jazz", "jazz"]))
  print(longestTwoGenreRun(["pop", "rock", "jazz", "pop", "jazz"]))
  print(longestTwoGenreRun([]))
  ```

  ```output
  4
  3
  0
  ```

  The window's state is a count per genre. The number of **different** genres is the number of keys, which is only true if a genre leaves the dictionary when its last track leaves the window; a key with count 0 would still count as a genre. In the first queue, "pop, rock, pop, rock" is 4; adding "jazz" forces the left end past every pop and all but the last rock. In the second, "jazz, pop, jazz" is 3.

  Each track enters once and leaves at most once, and each dictionary update is O(1) on average: **O(n) time on average**. The dictionary holds at most 3 keys at any moment, so its extra space is O(1).
````

````exercise
id: m16-l04-e6
type: design
prompt: |
  A stocks screen shows, for every window of k consecutive days, the **highest** price in that window. A teammate tries to reuse the running-sum trick: keep a running maximum, update it when a day enters, and "undo" it when a day leaves. Explain why that doesn't work, what the straightforward correct version costs, and what kind of state would be needed to do better.
rubric:
  - I explained that removing the maximum from the window leaves no way to know the next maximum from a single number.
  - I gave the straightforward version (compute max of each window) and its cost, O(n · k).
  - I said a sum works because subtraction undoes addition, and max has no such inverse.
  - I mentioned that keeping the window's candidates in order (a monotonic queue, Module 17) gives O(n).
solution: |
  A running sum can be updated in both directions because subtraction undoes addition: when a day leaves, you subtract it and the sum is exact again. A maximum has no inverse. If the day that leaves **was** the maximum, the single number you kept tells you nothing about the second highest price in the window. You'd have to look at the remaining k − 1 days again.

  The straightforward correct version computes `max()` over each window: n − k + 1 windows, k elements each, **O(n · k)**. For small k that's fine.

  To do better, the state must hold more than one number: the days that could still become the maximum of some future window, in decreasing order of price. A day that's lower than a later day can never be a window's maximum again, so it can be dropped. Kept in a double-ended queue, each day enters and leaves it once, and the front is always the current maximum: **O(n)** in total. That structure is a monotonic queue, and Module 17 builds it.
````

## Summary

- Window problems ask about **contiguous** stretches: consecutive, subarray, substring, in a row. Their state must be updatable in O(1) when one element enters or leaves.
- **Fixed size k**: add `values[right]`, subtract `values[right - k]` once `right >= k`, and read the answer once `right >= k - 1`. O(n) instead of O(n · k). Guard against k larger than the array.
- **Longest valid**: grow right, `while` invalid shrink left, then record `right - left + 1`. **Shortest valid**: grow right, `while` valid record and shrink.
- The variable window is **O(n)** because `left` only moves forward: at most n moves over the whole run, however the work is spread.
- State can be a sum, a `Set`, or a dictionary of counts (remove keys whose count reaches 0). Convert a `String` to `Array` before indexing it.
- The variable window needs a condition that only gets worse as the window grows. With negative numbers in a sum, it silently gives wrong answers: switch to prefix sums (lesson 6) or the brute force.
