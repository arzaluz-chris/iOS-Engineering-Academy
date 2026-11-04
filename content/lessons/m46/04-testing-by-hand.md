---
id: m46-l04
title: Testing by hand and debugging live
description: You learn to choose test cases that break code instead of confirming it, trace a function's variables in a table to find a bug before running anything, recognize the off-by-one errors that cause most interview bugs, and fix a bug calmly in front of someone, worked on a run-length encoder with two real bugs.
module: m46
order: 4
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m46-l03]
objectives:
  - Choose a small set of test cases that covers empty input, the smallest non-trivial input, boundaries and the case the algorithm depends on.
  - Trace a loop in a table with one row per iteration and one column per variable.
  - Recognize the common off-by-one errors in loop bounds, first and last elements, and ranges built from count.
  - Fix a bug by stating what you saw, a hypothesis, the smallest change and a full retest.
terms:
  - term: Trace table
    definition: A table with one column per variable and one row per loop iteration (or per step), filled in by hand to see exactly what the code does.
  - term: Off-by-one error
    definition: A bug where a loop or index goes one step too far or stops one step too short, like processing every element except the last.
  - term: Flush
    definition: Writing out state that a loop accumulated but hasn't emitted yet, usually needed once more after the loop ends.
  - term: Regression
    definition: A case that used to work and breaks after a change. Rerunning every test after a fix catches it.
mastery:
  - Pick five to eight test cases for a new function and say what each one is checking.
  - Fill in a trace table for a loop and point to the row where the result goes wrong.
  - Spot a missing final flush, a range built from count − 1 on empty input, and a <= that should be <.
  - Narrate a fix in four steps and rerun every test afterward.
resources: [swift-array, swift-book-control-flow, swift-book-strings, swift-precondition]
cards:
  - id: m46-l04-c1
    front: Which test cases should almost every array or string function get?
    back: "Empty; one element; two elements; all equal; all different; the interesting element at the very start and at the very end; the statement's example; and the case your idea depends on."
  - id: m46-l04-c2
    front: What's a trace table?
    back: One row per iteration and one column per variable, filled in by hand. The row where a value stops matching what you expect is where the bug is.
  - id: m46-l04-c3
    front: "Why does for i in 1..<values.count crash on an empty array?"
    back: "count is 0, so the range is 1..<0, and a range requires lowerBound <= upperBound. It stops with \"Range requires lowerBound <= upperBound\". Guard against empty input first."
  - id: m46-l04-c4
    front: What's the bug when a loop that groups runs gets every run except the last?
    back: The run is only written when the next element differs. After the loop, the last run is still pending and must be flushed once more.
  - id: m46-l04-c5
    front: The four steps of fixing a bug live?
    back: "1. Say what you saw (input, expected, actual). 2. Say why you think it happens. 3. Make the smallest change that fixes that cause. 4. Rerun every test, not just the one that failed."
---

## The idea in one sentence

Test with inputs chosen to **break** your code, trace them in a table so you see what each variable really holds, and when something's wrong, fix it in small, stated steps.

## Choosing test cases

The statement's example was chosen to explain the problem. It rarely breaks anything. These do:

| Case | Why it breaks things |
| --- | --- |
| Empty input | Ranges built from `count`, `first!`, `max()!`, division by `count` |
| One element | Loops that start at index 1 do nothing; neighbor comparisons have no neighbor |
| Two elements | The smallest case with a boundary between elements |
| All equal | Runs, duplicates, "strictly greater" versus "greater or equal" |
| All different | The opposite: nothing groups, nothing repeats |
| The answer at the very start or very end | First and last iterations are where off-by-one errors live |
| Extreme values | Negative numbers, zero, very large values (overflow) |
| The case your idea depends on | Remainder 0 in lesson 1, a missing ticket that's n in lesson 3 |

Pick five to eight. More than that and you won't have time to trace them; fewer and you'll miss the boundaries. Many come straight from the clarifying answers you wrote down (lesson 2).

## A function to test

Run-length encoding: replace each run of a repeated character with the character and the run's length, and leave single characters alone. `"aaabccdddd"` becomes `"a3bc2d4"`.

Here's a first version, as someone might write it under time pressure:

```swift
func compress(_ text: String) -> String {
    let characters = Array(text)
    var result = ""
    var runLength = 1
    for i in 1..<characters.count {
        if characters[i] == characters[i - 1] {
            runLength += 1
        } else {
            result.append(characters[i - 1])
            if runLength > 1 {
                result += String(runLength)
            }
            runLength = 1
        }
    }
    return result
}
```

The idea: compare each character with the one before it. While they match, the run grows; when they differ, the previous run is finished, so write it and start a new one.

## Tracing in a table

Before running anything, trace it on a small input. Take `"aab"`, the smallest input with both a run and a single character. `characters` is `["a", "a", "b"]`, and the loop runs for `i` = 1 and 2.

| i | characters[i − 1] | characters[i] | same? | runLength after | result after |
| --- | --- | --- | --- | --- | --- |
| (start) | | | | 1 | "" |
| 1 | a | a | yes | 2 | "" |
| 2 | a | b | no | 1 | "a2" |
| (end) | | | | 1 | "a2" |

The function returns `"a2"`, but the answer is `"a2b"`. The table shows why: a run is only written when the **next** character differs. The `b` is the last run, there's no next character, and the loop ends with it pending.

This is the most common bug in any loop that groups things (runs, streaks, sessions, intervals): **the last group needs a flush after the loop.**

Now trace the empty string. `characters.count` is 0, so the range is `1..<0`. That's not an empty range; it's an invalid one:

```swift runtime-error Range requires lowerBound <= upperBound
func compress(_ text: String) -> String {
    let characters = Array(text)
    var result = ""
    var runLength = 1
    for i in 1..<characters.count {
        if characters[i] == characters[i - 1] {
            runLength += 1
        } else {
            result.append(characters[i - 1])
            if runLength > 1 {
                result += String(runLength)
            }
            runLength = 1
        }
    }
    return result
}

print(compress("aaabccdddd"))
print(compress("ab"))
print(compress(""))
```

```output
a3bc2
a
```

The first two calls print the flush bug (`d4` and `b` are missing), and the third stops the program with `Fatal error: Range requires lowerBound <= upperBound`. Two bugs, found by two of the cases in the table at the top: the answer at the very end, and empty input.

## The usual off-by-one errors

Most interview bugs are one of these:

- **The last group is never emitted.** Flush after the loop.
- **A range built from `count` on empty input.** `1..<count`, `0...count - 1` and `0..<count - 1` are all invalid when `count` is 0. Handle empty input first with a `guard`, or loop over something that's naturally empty (`indices`, `zip(values, values.dropFirst())`).
- **`...` where you meant `..<`.** `0...values.count` reads one past the end.
- **`i + 1` or `i - 1` at the edges.** Reading a neighbor on the first or last iteration.
- **`<` versus `<=` in a `while` loop.** Ask whether the last remaining element still needs handling (Module 16).

Here's the third one, in a loop that counts days where a reading went up:

```swift runtime-error Index out of range
let readings = [3, 5, 4, 6]
var rises = 0
for i in 1...readings.count {
    if readings[i] > readings[i - 1] {
        rises += 1
    }
    print("checked day \(i)")
}
print(rises)
```

```output
checked day 1
checked day 2
checked day 3
```

`1...readings.count` is `1...4`, and `readings[4]` is one past the last index. The prints before the crash tell you how far it got: days 1 to 3 were fine, and the fourth iteration failed. `1..<readings.count` fixes it, and so does `zip(readings, readings.dropFirst())`, which also handles an empty array.

## Fixing it calmly

When a trace or a test shows a bug, go through four steps, out loud:

1. **Say what you saw.** "For `"ab"` I get `"a"`; the `b` is missing. For the empty string it crashes on the range."
2. **Say why.** "Runs are only written when the next character differs, so the last run is never written. And `1..<0` is an invalid range."
3. **Make the smallest change that fixes that cause.** A `guard` for empty input, and one flush after the loop. Don't rewrite the function.
4. **Rerun every test**, not just the one that failed. A fix for the last run could break the first one (a regression).

The fixed version, with the flush pulled into a small helper so the loop and the end share it:

```swift
func compress(_ text: String) -> String {
    let characters = Array(text)
    guard let first = characters.first else { return "" }
    var result = ""
    var current = first
    var runLength = 1

    func flush() {
        result.append(current)
        if runLength > 1 {
            result += String(runLength)
        }
    }

    for character in characters.dropFirst() {
        if character == current {
            runLength += 1
        } else {
            flush()
            current = character
            runLength = 1
        }
    }
    flush()
    return result
}

let cases: [(input: String, expected: String)] = [
    ("aaabccdddd", "a3bc2d4"),
    ("", ""),
    ("a", "a"),
    ("ab", "ab"),
    ("aab", "a2b"),
    ("abb", "ab2"),
    ("zzzz", "z4"),
    ("aaaaaaaaaaaa", "a12"),
]
for (input, expected) in cases {
    let actual = compress(input)
    print(actual == expected ? "pass" : "FAIL", "[\(input)] -> [\(actual)]")
}
```

```output
pass [aaabccdddd] -> [a3bc2d4]
pass [] -> []
pass [a] -> [a]
pass [ab] -> [ab]
pass [aab] -> [a2b]
pass [abb] -> [ab2]
pass [zzzz] -> [z4]
pass [aaaaaaaaaaaa] -> [a12]
```

What changed, and what each test is for:

- `guard let first = characters.first` handles empty input before any range is built, and gives the first run its character.
- `characters.dropFirst()` replaces `1..<characters.count`. It's simply empty when there's one character, so there's no range to get wrong.
- `flush()` is a nested function: it can read and change `result`, `current` and `runLength` from the enclosing function. It runs once per finished run and **once after the loop**, for the last run.
- The tests cover the statement's example, empty, one character, two different, a run at the start, a run at the end, all equal, and a run longer than 9 (to make sure the count isn't treated as a single digit).

O(n) time for n characters. The output is never longer than the input: a single character stays one character, and a run of k ≥ 2 characters becomes the character plus the digits of k, which is at most k characters. So O(n) space for the result.

## When you can run code

Some interviews let you run code; many don't. When you can, two habits help:

- **Print the state inside the loop**, exactly like the trace table, then delete the print once you've found the problem.
- **Compare against the brute force** on small inputs, as in lesson 1, when there is one.

When you can't run code, the trace table is your debugger. Trace at least one ordinary case and one edge case before you say "done".

## Common mistakes

> [!error] Testing only cases you expect to pass
> If every test you pick confirms the code, they're not tests. Pick the ones from the table at the top, especially empty and "the answer is at the very end".

> [!error] Tracing what you meant instead of what you wrote
> Read each line as written. The `1..<characters.count` bug is invisible if you trace with "and then it handles the rest".

> [!error] Changing several things at once
> If you change three lines and the test passes, you don't know which change fixed it, or whether another one broke something. One cause, one change, then retest.

> [!error] Retesting only the failing case
> The fix for the last run could have broken the first. Rerun the whole list; it's why you wrote it.

> [!error] Leaving debug prints in the final answer
> Prints inside a loop change the output and make an O(n) function slow. Remove them, and say that you did.

## Exercises

````exercise
id: m46-l04-e1
type: prediction
prompt: This function should return the length of the longest run of equal values. Predict the output, then name the bug.
code: |
  func longestRun(_ values: [Int]) -> Int {
      var longest = 0
      var current = 1
      for i in 1..<max(values.count, 1) {
          if values[i] == values[i - 1] {
              current += 1
          } else {
              longest = max(longest, current)
              current = 1
          }
      }
      return longest
  }

  print(longestRun([1, 1, 2, 2, 2]))
  print(longestRun([4, 4, 4, 1]))
  print(longestRun([7]))
output: |
  2
  3
  0
hints:
  - "longest is only updated when two neighbors differ."
  - "For [7], the range is 1..<1. How many times does the loop run?"
solution: |
  ```output
  2
  3
  0
  ```

  The same bug as the run-length encoder: `longest` is only updated when a run **ends because the next value differs**. In `[1, 1, 2, 2, 2]` the last run (three 2s) never gets compared, so the answer is 2 instead of 3. In `[4, 4, 4, 1]` the long run ends before the last element, so it's counted. For `[7]` the loop never runs, and `longest` stays 0 instead of 1.

  The fix is one more update after the loop: `return max(longest, current)`. Then `[7]` gives 1. An empty array would still need its own answer (0) and a guard, because `current` starts at 1. The `max(values.count, 1)` trick only avoids the crash; it doesn't make the answer right.
````

````exercise
id: m46-l04-e2
type: comprehension
prompt: You have time to trace four cases for a function that returns the index of the first element greater than its left neighbor, or nil. Which set is best?
choices:
  - text: "[], [5], [5, 3, 2], [1, 3]"
    correct: true
    why: Empty, one element, no answer (all decreasing), and the smallest input with an answer at the very end.
  - text: "[1, 3, 2], [2, 5, 1], [0, 9, 4], [3, 7, 7]"
    correct: false
    why: Four variations of the same shape, all with the answer at index 1. None tests empty, one element or no answer.
  - text: "The statement's example, four times with different numbers"
    correct: false
    why: Repeating the example confirms one shape over and over.
  - text: "[1, 2, 3, ..., 1000] and its reverse"
    correct: false
    why: Too long to trace by hand, and they miss empty and one element.
solution: |
  The first set. Each case checks something different: empty (ranges built from `count`), one element (no neighbor), no answer at all (the `nil` path), and the answer at the last possible index (the last iteration). The others repeat one shape, which is what the statement's example already gave you.
````

````exercise
id: m46-l04-e3
type: fill-in
prompt: Complete the fixed `longestRun` so it handles empty input and the last run. It should print `3`, `1` and `0`.
code: |
  func longestRun(_ values: [Int]) -> Int {
      guard let first = values.[[1]] else { return 0 }
      var longest = 1
      var current = 1
      var previous = first
      for value in values.[[2]]() {
          if value == previous {
              current += 1
              longest = [[3]](longest, current)
          } else {
              current = 1
          }
          previous = value
      }
      return longest
  }

  print(longestRun([1, 1, 2, 2, 2]))
  print(longestRun([7]))
  print(longestRun([]))
blanks:
  - id: "1"
    answers: ["first"]
  - id: "2"
    answers: ["dropFirst"]
  - id: "3"
    answers: ["max"]
solution: |
  ```swift
  func longestRun(_ values: [Int]) -> Int {
      guard let first = values.first else { return 0 }
      var longest = 1
      var current = 1
      var previous = first
      for value in values.dropFirst() {
          if value == previous {
              current += 1
              longest = max(longest, current)
          } else {
              current = 1
          }
          previous = value
      }
      return longest
  }

  print(longestRun([1, 1, 2, 2, 2]))
  print(longestRun([7]))
  print(longestRun([]))
  ```

  ```output
  3
  1
  0
  ```

  This version avoids the flush entirely by updating `longest` every time the run grows, so the last run is already counted when the loop ends. Both styles are fine: flush at the end, or update on every step. The `guard` handles empty input before anything else, and `dropFirst()` is empty for a one-element array, so no range can be invalid.
````

````exercise
id: m46-l04-e4
type: solve
prompt: |
  Write the inverse: `func decompress(_ text: String) -> String` turns `"a3bc2"` into `"aaabcc"`. A letter with no number after it appears once. Counts can have more than one digit (`"x12"` is twelve x's). Assume the input is valid: it starts with a letter, letters aren't digits, and digits are ASCII 0 to 9.

  Before writing it, list the test cases you'll use and what each checks. Expected output for the starter's calls:

  ```output
  [aaabcc]
  [xxxxxxxxxxxx]
  []
  [abc]
  [a]
  ```
starter: |
  func decompress(_ text: String) -> String {
      return ""
  }

  for text in ["a3bc2", "x12", "", "abc", "a1"] {
      print("[\(decompress(text))]")
  }
hints:
  - Keep the current letter and the digits seen after it. When a new letter arrives, the previous letter is complete.
  - Like the encoder, the last letter is still pending when the loop ends.
  - "(\"0\"...\"9\").contains(character) checks for an ASCII digit."
rubric:
  - Lists test cases before coding, each with a purpose (multi-digit count, empty, no counts, a count of 1).
  - Accumulates multi-digit counts instead of reading one digit.
  - Flushes the last letter after the loop.
  - The output matches.
solution: |
  Test cases and what each checks: `"a3bc2"` (the example, with a letter that has no count), `"x12"` (a two-digit count), `""` (empty), `"abc"` (no counts at all), `"a1"` (an explicit count of 1).

  ```swift
  func decompress(_ text: String) -> String {
      var result = ""
      var current: Character?
      var digits = ""

      func flush() {
          guard let letter = current else { return }
          let count = Int(digits) ?? 1
          result += String(repeating: letter, count: count)
      }

      for character in text {
          if ("0"..."9").contains(character) {
              digits.append(character)
          } else {
              flush()
              current = character
              digits = ""
          }
      }
      flush()
      return result
  }

  for text in ["a3bc2", "x12", "", "abc", "a1"] {
      print("[\(decompress(text))]")
  }
  ```

  ```output
  [aaabcc]
  [xxxxxxxxxxxx]
  []
  [abc]
  [a]
  ```

  `current` starts as `nil`, so the first `flush()` (before any letter) does nothing, and so does the final one for empty input. Digits are collected as a string and converted once, which handles `"12"` correctly; reading one digit at a time would produce one x, then two x's. `Int(digits) ?? 1` covers a letter with no digits. The time is proportional to the length of the **output**, which can be much longer than the input: `"a999"` is 4 characters in and 999 out.
````

````exercise
id: m46-l04-e5
type: find-errors
prompt: This function should return the largest difference between consecutive readings (later minus earlier), or nil if there are fewer than two. Which statements are true?
code: |
  func largestJump(_ readings: [Int]) -> Int? {
      var largest = 0
      for i in 0..<readings.count - 1 {
          largest = max(largest, readings[i + 1] - readings[i])
      }
      return largest
  }
choices:
  - text: "With an empty array, 0..<readings.count - 1 is 0..<-1 and the program stops."
    correct: true
    why: A range needs lowerBound <= upperBound.
  - text: "With one reading, it returns 0 instead of nil."
    correct: true
    why: The range is 0..<0, the loop doesn't run, and largest is returned as is.
  - text: "If every reading goes down, it returns 0 instead of the largest (least negative) jump."
    correct: true
    why: Starting at 0 means a negative jump can never win. Start from the first actual difference instead.
  - text: "readings[i + 1] reads past the end on the last iteration."
    correct: false
    why: The last i is count − 2, so i + 1 is count − 1, the last valid index.
rubric:
  - I found the crash on empty input and the wrong answer for one reading.
  - I noticed that the initial value 0 hides negative answers.
  - I fixed all three with a guard for count < 2 and an initial value taken from the data.
solution: |
  Three bugs, and none shows up on an ordinary example like `[1, 4, 2, 9]`. They come from three test cases: empty, one element, all decreasing. A fixed version:

  ```swift
  func largestJump(_ readings: [Int]) -> Int? {
      guard readings.count >= 2 else { return nil }
      var largest = readings[1] - readings[0]
      for (earlier, later) in zip(readings, readings.dropFirst()) {
          largest = max(largest, later - earlier)
      }
      return largest
  }

  print(largestJump([1, 4, 2, 9]) ?? "nil")
  print(largestJump([]) ?? "nil")
  print(largestJump([5]) ?? "nil")
  print(largestJump([9, 7, 6]) ?? "nil")
  ```

  ```output
  7
  nil
  nil
  -1
  ```

  `zip(readings, readings.dropFirst())` pairs each reading with the next one and stops at the shorter sequence, so there's no index arithmetic to get wrong. Starting `largest` from a real difference (instead of 0) lets an all-negative answer come out right.
````

````exercise
id: m46-l04-e6
type: explain
prompt: |
  A candidate traced their "count the vowels in each word" function on `"hi you"` and got this table. The expected result is `[1, 2]`. Using only the table, explain where it goes wrong and what the bug probably is.

  | character | vowels in current word | result |
  | --- | --- | --- |
  | (start) | 0 | [] |
  | h | 0 | [] |
  | i | 1 | [] |
  | (space) | 0 | [1] |
  | y | 0 | [1] |
  | o | 1 | [1] |
  | u | 2 | [1] |
  | (end) | 2 | [1] |
code: |
  // The candidate's code isn't shown; work from the table.
rubric:
  - I pointed to the (end) row as where the result stops matching.
  - I explained that a word's count is only appended at a space, so the last word is never appended.
  - I proposed appending once more after the loop (and thought about input ending in a space or empty input).
solution: |
  Every row until the end matches what you'd expect: the count resets at the space and the first word's 1 is appended. The problem is the `(end)` row: the current count is 2, but `result` is still `[1]`. A word's count is only appended **when a space arrives**, and the last word isn't followed by one. It's the same missing flush as the run-length encoder.

  The fix is to append the current count once more after the loop. Then check the new edge cases the fix creates: `"hi "` (ending in a space) would now append an extra 0 for an empty last word, and `""` would produce `[0]`. Decide with the interviewer what those should return, and flush only if the current word is non-empty if `[]` is the expected answer.
````

## Summary

- Pick test cases to **break** the code: empty, one element, two elements, all equal, all different, the answer at the very start or end, extreme values, and the case your idea depends on.
- Trace in a table, one row per iteration and one column per variable. The row where a value stops matching your expectation is the bug.
- The usual suspects: a last group that's never flushed, ranges built from `count` on empty input (`1..<0` stops the program), `...` instead of `..<`, neighbors at the edges, and `<` versus `<=`.
- `guard let first = values.first`, `dropFirst()` and `zip(values, values.dropFirst())` avoid most index arithmetic.
- Fix in four steps: say what you saw, say why, make the smallest change, rerun every test.
