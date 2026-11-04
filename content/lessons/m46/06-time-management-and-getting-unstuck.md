---
id: m46-l06
title: Time management and getting unstuck
description: You get the course's 45-minute plan for a coding problem with checkpoints, learn the signals that you're stuck and specific hints worth asking for, see what to do when only five minutes are left, and recover from a wrong first approach by finding a counterexample with an exhaustive brute-force checker and repairing the idea instead of starting over.
module: m46
order: 6
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m46-l05]
objectives:
  - Split a 45-minute session across the four phases of the method and check progress at fixed checkpoints.
  - Recognize the signals that you're stuck and use a technique to get moving again.
  - Ask for a specific hint that shows what you already know.
  - Use the last five minutes to leave a correct, explained answer, even if it's incomplete.
  - Find a counterexample to a wrong approach with an exhaustive checker over small inputs, and repair the approach.
terms:
  - term: Checkpoint
    definition: A minute mark at which you check whether you've reached a given step, and change course if you haven't, for example "brute force with complexity by minute 12".
  - term: Exhaustive checker
    definition: A small program that runs a fast solution and a brute force on every input up to a small size and reports the first disagreement.
  - term: Counterexample
    definition: One concrete input on which a proposed solution gives the wrong answer. A single one is enough to show the approach is wrong.
  - term: Specific hint
    definition: A question to the interviewer that states what you've tried and narrows down what you need, rather than "can I have a hint?".
mastery:
  - Lay out a 45-minute plan with times for each phase and three checkpoints.
  - Name at least four signals that you're stuck and a technique for each.
  - Turn "I'm stuck" into a specific hint request.
  - Write an exhaustive checker that compares a candidate with a brute force on all small inputs.
  - Repair a wrong approach using the counterexample, and state the new complexity.
resources: [swift-array, swift-array-sort, swift-precondition, swift-book-control-flow]
cards:
  - id: m46-l06-c1
    front: The course's 45-minute plan for a coding problem?
    back: "About 5 minutes understanding (steps 1–4), 7 exploring (5–8), 3 planning, 15 coding, 7 testing and debugging, 5 wrapping up, and 3 of buffer or your own questions."
  - id: m46-l06-c2
    front: What are the three checkpoints?
    back: "Minute 12, a brute force with its complexity. Minute 15, an agreed plan. Minute 20, code on the screen; if not, code the brute force now."
  - id: m46-l06-c3
    front: Name four signals that you're stuck.
    back: "Circling the same idea for several minutes; not being able to state why the idea works; code that keeps growing special cases; a trace that contradicts the code and you can't say why. Long silence is a fifth."
  - id: m46-l06-c4
    front: What do you do with five minutes left and unfinished code?
    back: "Stop adding features. Make the main path correct, write the missing pieces as comments, trace one case, then state the complexity and exactly what's left."
  - id: m46-l06-c5
    front: How do you find out quickly that an approach is wrong?
    back: Run it against a brute force on every small input (an exhaustive checker), or hunt for a counterexample by hand with negatives, zeros, duplicates and the smallest sizes.
---

## The idea in one sentence

Time runs out on people who don't watch it, so set checkpoints, notice early when you're stuck, ask for specific help, and when an approach turns out wrong, repair it from the counterexample instead of starting over.

## A 45-minute plan

Interview formats vary, and nothing here describes a specific company. This is the course's suggestion for a 45-minute slot with one problem. If introductions take five minutes, shrink every phase proportionally; the order and the checkpoints still apply.

| Minutes | Phase | Steps | Done when |
| --- | --- | --- | --- |
| 0–5 | Understand | 1–4 | You've restated the problem, asked your questions and listed edge cases |
| 5–12 | Explore | 5–8 | You've said the brute force with its cost and have a better idea, or decided the brute force is enough |
| 12–15 | Plan | 9 | The interviewer has seen the plan and not objected |
| 15–30 | Code | 10 | The function is written |
| 30–37 | Test and debug | 11–12 | You've traced at least one ordinary case and one edge case, and fixed what they found |
| 37–42 | Wrap up | 13–15 | You've stated time and space, a trade-off, and answered a follow-up |
| 42–45 | Buffer | | Overruns, or your questions for the interviewer |

Coding gets the largest block, but it's only a third of the time. Most of what an interviewer evaluates happens in the other two-thirds.

**Checkpoints.** Glance at the clock at three moments:

- **Minute 12:** do you have a brute force and its complexity? If not, stop looking for clever ideas and say the brute force now.
- **Minute 15:** has the interviewer seen a plan? If you're still exploring, pick the best idea you have and plan it.
- **Minute 20:** is there code on the screen? If not, code the brute force. A correct O(n²) answer with a described O(n) improvement is a much better outcome than an unfinished O(n) one.

## Signals you're stuck

Being stuck isn't the problem; staying stuck without noticing is. Watch for these:

| Signal | What to do |
| --- | --- |
| You've circled the same idea for three or four minutes | Say it out loud, with its flaw: "Sorting gets me O(n log n), and I keep failing to avoid the sort." |
| You can't say *why* your idea works | Trace it on the smallest example where it matters. If it fails, you've learned something; if it works, the trace often shows the reason. |
| The code keeps growing special cases | Step back to the plan. Special cases piling up usually mean the main idea is slightly off. |
| A trace contradicts the code and you don't know why | Shrink the input until the bug is on one or two lines (lesson 4). |
| You've been silent for a while | Say where you are, even if it's "I'm stuck on how to handle duplicates." |

And techniques that get you moving:

- **Solve tiny examples by hand** and watch what *you* do. Your hands often find the algorithm before your head names it.
- **Go through the signals tables** from Modules 16 to 20: sorted input, "in place", pairs, windows, "count the ways", intervals. One of them usually matches.
- **Change the representation**: sort it, count it, take prefix sums, build a graph.
- **Solve a simpler version**: no duplicates, only positive numbers, k = 2. Then add the complication back.
- **Work backward from the complexity.** If the constraints demand O(n log n), something is sorted or halved. If O(n), it's probably one pass with a set, a dictionary, two pointers or a stack.

## Asking for a hint

Asking for help is part of the conversation, not a failure. How you ask matters. "Can I have a hint?" gives the interviewer nothing to work with. A specific request shows what you know and lets them give a small nudge instead of the answer:

- "I have O(n log n) with sorting. Are you looking for O(n)?"
- "I think I need to remember something about each element I've passed, but I'm not sure what. Am I on the right track with a dictionary?"
- "This works except when values repeat. Is it OK to assume they're distinct for now and come back to it?"
- "Is there a property of the input I'm not using? I haven't used the fact that it's sorted."

When you get a hint, **use it out loud**: "So if I keep the smallest value seen so far, then for each day I…". It shows you understood it, and if you didn't, the interviewer can correct you right away.

## Five minutes left

If the clock says five minutes and the code isn't finished, change goals: leave a **correct, explained, partial** answer.

1. **Stop adding features.** Don't start the optimization or the extra edge case now.
2. **Make the main path correct.** A solution that handles the normal case and says "empty input isn't handled yet" is better than one that tries everything and handles nothing.
3. **Write the missing pieces as comments.** They show you know what's missing.
4. **Trace one case** on what you have.
5. **State complexity and what's left**: "This is O(n) time, O(n) space. What's missing is the case where the window is empty; it'd need a guard at the top."

Here's what that might look like for a function that returns the indices of the two largest values, with the main path done and the rest written down:

```swift
func twoLargestIndices(_ values: [Int]) -> (first: Int, second: Int) {
    // Assumes values.count >= 2. Not handled yet: fewer than two values
    // (would return nil with an optional return type).
    var first = values[0] >= values[1] ? 0 : 1
    var second = 1 - first
    for index in 2..<values.count {
        if values[index] > values[first] {
            second = first
            first = index
        } else if values[index] > values[second] {
            second = index
        }
    }
    return (first, second)
}

let result = twoLargestIndices([4, 9, 2, 7])
print(result.first, result.second)
```

```output
1 3
```

The comment says what's assumed and what's missing. One trace on `[4, 9, 2, 7]` shows the main path works. With an array of exactly two values, the range `2..<2` is empty and the loop is skipped; with fewer, the function would crash on `values[1]`, which is exactly what the comment says. That's an honest answer with five minutes of work left, and the interviewer can see all of it.

## Recovering from a wrong approach

Sometimes the plan was wrong. That's normal; what matters is how quickly you find out and how you recover.

> Return the largest product of two different elements of an array (at least two elements, values can be negative).

A first approach: "Sort and multiply the two largest. O(n log n)." It sounds right, and it passes the obvious example `[3, 7, 1]`.

### Find the counterexample

Instead of hoping, check it. An **exhaustive checker** runs the candidate and a brute force on every array up to a small size and reports the first disagreement:

```swift
func largestProductGuess(_ values: [Int]) -> Int {
    let sorted = values.sorted()
    return sorted[sorted.count - 1] * sorted[sorted.count - 2]
}

func largestProductBruteForce(_ values: [Int]) -> Int {
    var best = Int.min
    for i in values.indices {
        for j in (i + 1)..<values.count {
            best = max(best, values[i] * values[j])
        }
    }
    return best
}

func allArrays(length: Int, from range: ClosedRange<Int>) -> [[Int]] {
    if length == 0 {
        return [[]]
    }
    var result: [[Int]] = []
    for shorter in allArrays(length: length - 1, from: range) {
        for value in range {
            result.append(shorter + [value])
        }
    }
    return result
}

search: for length in 2...4 {
    for values in allArrays(length: length, from: -2...2) {
        let guess = largestProductGuess(values)
        let expected = largestProductBruteForce(values)
        if guess != expected {
            print("counterexample:", values, "guess", guess, "expected", expected)
            break search
        }
    }
}
```

```output
counterexample: [-2, -2, -1] guess 2 expected 4
```

- `allArrays(length:from:)` builds every array of the given length from a small range of values, recursively (Module 18): every shorter array, extended by each value. There are 5³ = 125 arrays of length 3 over −2...2, so this runs instantly.
- `search:` is a **label** on the outer loop, and `break search` leaves both loops at once (the Swift book's Control Flow chapter covers labeled statements).
- No length-2 array disagrees, because with two values both functions multiply the same pair. The first counterexample has length 3: two negatives.

In an interview without a computer you do the same search by hand: try negatives, zeros, duplicates and the smallest sizes. Here, "two large negatives" is the case to try, and it takes one line to find: `[-5, -4, 1, 2]` gives 2 from the guess, but −5 × −4 = 20.

### Repair, don't restart

The counterexample doesn't mean the whole idea is wrong. It shows exactly what's missing: two negatives multiply to a positive, so the answer is the larger of **the two largest values' product** and **the two smallest values' product**. That's one line added to the sorted version. Say it like that:

> "My approach misses two large negatives, like −5 and −4. The fix is to also consider the two smallest values and take the larger product. I don't even need to sort: I can track the two largest and two smallest in one pass."

The one-pass version, checked against the brute force on every array up to length 5 over −3...3:

```swift
func largestProduct(_ values: [Int]) -> Int {
    precondition(values.count >= 2, "Need at least two values")
    var largest = Int.min
    var secondLargest = Int.min
    var smallest = Int.max
    var secondSmallest = Int.max
    for value in values {
        if value > largest {
            secondLargest = largest
            largest = value
        } else if value > secondLargest {
            secondLargest = value
        }
        if value < smallest {
            secondSmallest = smallest
            smallest = value
        } else if value < secondSmallest {
            secondSmallest = value
        }
    }
    return max(largest * secondLargest, smallest * secondSmallest)
}

func largestProductBruteForce(_ values: [Int]) -> Int {
    var best = Int.min
    for i in values.indices {
        for j in (i + 1)..<values.count {
            best = max(best, values[i] * values[j])
        }
    }
    return best
}

func allArrays(length: Int, from range: ClosedRange<Int>) -> [[Int]] {
    if length == 0 {
        return [[]]
    }
    var result: [[Int]] = []
    for shorter in allArrays(length: length - 1, from: range) {
        for value in range {
            result.append(shorter + [value])
        }
    }
    return result
}

var checked = 0
var mismatches = 0
for length in 2...5 {
    for values in allArrays(length: length, from: -3...3) {
        checked += 1
        if largestProduct(values) != largestProductBruteForce(values) {
            mismatches += 1
        }
    }
}
print(checked, "arrays checked,", mismatches, "mismatches")
print(largestProduct([-5, -4, 1, 2]), largestProduct([3, 7]), largestProduct([-1, 0, 1]))
```

```output
19600 arrays checked, 0 mismatches
20 21 0
```

O(n) time, O(1) space, and every array of length 2 to 5 over −3...3 agrees with the brute force. An exhaustive check over small inputs isn't a proof, but it catches most wrong ideas, because wrong ideas usually fail on small, odd cases like two negatives.

The two `if` chains are separate on purpose: the same value can be both among the largest and among the smallest (in a two-element array, each value is both).

A note on overflow (lesson 5): with values near `Int.max`, the products can overflow. If the constraints allow huge values, say so and use `multipliedReportingOverflow(by:)`.

## Common mistakes

> [!error] Not looking at the clock until minute 35
> Without checkpoints, the explore phase quietly eats the coding time. Check at minutes 12, 15 and 20.

> [!error] Holding out for the optimal solution
> If minute 20 arrives and nothing is on the screen, code the brute force. You can still describe the better approach in the wrap-up.

> [!error] "Can I have a hint?" with no context
> Say what you've tried and where you're stuck. A specific question gets a small nudge; a vague one gets either nothing or the whole answer.

> [!error] Starting over after a counterexample
> A counterexample tells you exactly what the approach misses. Most of the time the repair is small: consider one more case, track one more value.

> [!error] Hiding an unfinished part
> Pretending a solution is complete when it isn't is worse than saying what's missing. Write it in a comment and say it.

## Exercises

````exercise
id: m46-l06-e1
type: comprehension
prompt: It's minute 21. You have a plan for an O(n) solution, but you're not sure it handles duplicates, and you haven't written any code. What does the course's plan suggest?
choices:
  - text: "Code the brute force now, say so, and describe the O(n) idea and its open question about duplicates."
    correct: true
    why: The minute-20 checkpoint has passed with no code. A working answer plus a described improvement is the safer outcome.
  - text: Keep thinking about duplicates until you're sure, then code the O(n) version.
    correct: false
    why: There's no limit on how long "until you're sure" takes, and coding time is already being used up.
  - text: Start coding the O(n) version and hope duplicates work out.
    correct: false
    why: Possible if you say the risk out loud, but the checkpoint exists so you have something correct first.
  - text: Ask the interviewer to give you the answer for duplicates.
    correct: false
    why: A specific question about duplicates is fine. Asking for the answer isn't the same thing, and it doesn't fix the time problem.
solution: |
  **Code the brute force.** The minute-20 checkpoint says that if there's no code on the screen, the brute force goes in now. Say it: "I'm going to write the O(n²) version so we have something correct, then come back to the O(n) idea. My open question there is duplicates." If time remains after testing it, you can still write the O(n) version; if not, you've described it.
````

````exercise
id: m46-l06-e2
type: prediction
prompt: A candidate guessed answers for "largest product of three different elements" and checks them against a brute force. Predict the output.
code: |
  func bruteForce(_ values: [Int]) -> Int {
      var best = Int.min
      for i in values.indices {
          for j in (i + 1)..<values.count {
              for k in (j + 1)..<values.count {
                  best = max(best, values[i] * values[j] * values[k])
              }
          }
      }
      return best
  }

  let guesses: [(values: [Int], guess: Int)] = [
      ([1, 2, 3], 6),
      ([-4, -3, 2], 6),
      ([0, -1, -2], 0),
  ]
  for (values, guess) in guesses {
      let expected = bruteForce(values)
      print(values, guess == expected ? "ok" : "expected \(expected)")
  }
output: |
  [1, 2, 3] ok
  [-4, -3, 2] expected 24
  [0, -1, -2] ok
hints:
  - Each array has exactly three elements, so there's only one triple.
  - "(-4) × (-3) × 2"
solution: |
  ```output
  [1, 2, 3] ok
  [-4, -3, 2] expected 24
  [0, -1, -2] ok
  ```

  With three elements there's one triple, so the brute force is just the product: 6, 24 and 0. The second guess (6) probably came from multiplying absolute values wrongly or from a "three largest" rule; two negatives make a positive. That's the same lesson as the two-element version, and the reason the exercise below has to consider the two smallest values.
````

````exercise
id: m46-l06-e3
type: solve
prompt: |
  Follow-up: return the largest product of **three** different elements (at least three elements; values can be negative). Your first idea is "the three largest". Find the case it misses, repair it, and write `largestProductOfThree` in O(n log n) with sorting. Then verify it against the brute force on every array of length 3 to 5 over −3...3. Expected output:

  ```output
  0 mismatches
  270 6 -24
  ```
starter: |
  func largestProductOfThree(_ values: [Int]) -> Int {
      return 0
  }

  func bruteForce(_ values: [Int]) -> Int {
      var best = Int.min
      for i in values.indices {
          for j in (i + 1)..<values.count {
              for k in (j + 1)..<values.count {
                  best = max(best, values[i] * values[j] * values[k])
              }
          }
      }
      return best
  }

  func allArrays(length: Int, from range: ClosedRange<Int>) -> [[Int]] {
      if length == 0 {
          return [[]]
      }
      var result: [[Int]] = []
      for shorter in allArrays(length: length - 1, from: range) {
          for value in range {
              result.append(shorter + [value])
          }
      }
      return result
  }

  var mismatches = 0
  for length in 3...5 {
      for values in allArrays(length: length, from: -3...3)
      where largestProductOfThree(values) != bruteForce(values) {
          mismatches += 1
      }
  }
  print(mismatches, "mismatches")
  print(largestProductOfThree([-10, -9, 1, 2, 3]),
        largestProductOfThree([1, 2, 3]),
        largestProductOfThree([-5, -4, -3, -2]))
hints:
  - "Try [-10, -9, 1, 2, 3]: the three largest give 6."
  - A product of three is positive with zero or two negatives. Two negatives should be the two smallest values, and the third factor the largest.
rubric:
  - Names the counterexample (two large negatives) before repairing.
  - Takes the maximum of the three largest and the two smallest times the largest.
  - The checker reports 0 mismatches and the three calls match.
  - States O(n log n) time with sorting (and mentions an O(n) version that tracks three largest and two smallest).
solution: |
  The counterexample: `[-10, -9, 1, 2, 3]`. The three largest give 1 × 2 × 3 = 6, but −10 × −9 × 3 = 270. The repair: the answer is either the three largest, or the two smallest (both negative, so their product is positive) times the largest.

  ```swift
  func largestProductOfThree(_ values: [Int]) -> Int {
      let sorted = values.sorted()
      let n = sorted.count
      let threeLargest = sorted[n - 1] * sorted[n - 2] * sorted[n - 3]
      let twoSmallestAndLargest = sorted[0] * sorted[1] * sorted[n - 1]
      return max(threeLargest, twoSmallestAndLargest)
  }

  func bruteForce(_ values: [Int]) -> Int {
      var best = Int.min
      for i in values.indices {
          for j in (i + 1)..<values.count {
              for k in (j + 1)..<values.count {
                  best = max(best, values[i] * values[j] * values[k])
              }
          }
      }
      return best
  }

  func allArrays(length: Int, from range: ClosedRange<Int>) -> [[Int]] {
      if length == 0 {
          return [[]]
      }
      var result: [[Int]] = []
      for shorter in allArrays(length: length - 1, from: range) {
          for value in range {
              result.append(shorter + [value])
          }
      }
      return result
  }

  var mismatches = 0
  for length in 3...5 {
      for values in allArrays(length: length, from: -3...3)
      where largestProductOfThree(values) != bruteForce(values) {
          mismatches += 1
      }
  }
  print(mismatches, "mismatches")
  print(largestProductOfThree([-10, -9, 1, 2, 3]),
        largestProductOfThree([1, 2, 3]),
        largestProductOfThree([-5, -4, -3, -2]))
  ```

  ```output
  0 mismatches
  270 6 -24
  ```

  For all negatives (`[-5, -4, -3, -2]`), the three largest are −4, −3 and −2, product −24, and the other candidate is −5 × −4 × −2 = −40, so −24 wins. The checker covers 7³ + 7⁴ + 7⁵ = 19,551 arrays.

  O(n log n) for the sort. Tracking the three largest and two smallest in one pass, as in the two-element version, makes it O(n) time and O(1) space; mention it in the wrap-up.
````

````exercise
id: m46-l06-e4
type: comprehension
multiple: true
prompt: Which of these are good hint requests? Select all that apply.
choices:
  - text: "\"I can do it in O(n log n) by sorting. Is O(n) expected?\""
    correct: true
    why: States what you have and asks about the target.
  - text: "\"Can you just tell me which data structure to use?\""
    correct: false
    why: Asks for the answer instead of a nudge, and shows nothing about your thinking.
  - text: "\"My window logic works unless the same value appears twice. Can I assume distinct values for now?\""
    correct: true
    why: Precise about the problem and proposes a way forward.
  - text: "\"I haven't used the fact that the input is sorted. Is that the key?\""
    correct: true
    why: Points to a specific unused property, which is often exactly where the solution is.
  - text: "\"Hint?\""
    correct: false
    why: Gives the interviewer nothing to aim the hint at.
solution: |
  Good hint requests say what you've done and point at a specific gap: the target complexity, a case that breaks your idea, or an unused property of the input. They let the interviewer give a small push, and they show your reasoning even while you're stuck. "Hint?" and "just tell me" do neither.
````

````exercise
id: m46-l06-e5
type: design
prompt: |
  Plan a 45-minute session for this problem, as if you were about to start:

  > Given a list of meeting start and end times, return the minimum number of rooms needed so no two overlapping meetings share a room. Up to 10⁴ meetings.

  Give each phase a time, write what you'd say at each checkpoint (minutes 12, 15 and 20), and write the comment you'd leave if you had five minutes left with only the sorting done.
rubric:
  - Times for all phases add up to 45 and follow the order of the method.
  - "The minute-12 statement includes a brute force with its cost (for example, checking each meeting against all others, O(n²))."
  - The minute-15 statement is a concrete plan (for example, sort starts and ends, sweep with two pointers, O(n log n)).
  - The minute-20 statement says what you'll do if no code exists yet.
  - The five-minutes-left comment says what's done, what's missing and the intended complexity.
solution: |
  A possible plan:

  | Minutes | Phase | Notes |
  | --- | --- | --- |
  | 0–5 | Understand | Do meetings that end at 10 and start at 10 overlap? Empty list returns 0. Times are integers. |
  | 5–12 | Explore | Brute force, pattern (intervals, Module 20) |
  | 12–15 | Plan | Sweep |
  | 15–30 | Code | |
  | 30–37 | Test | Empty, one meeting, all overlapping, touching end and start, nested meetings |
  | 37–42 | Wrap up | Complexity, heap alternative, follow-up |
  | 42–45 | Buffer | |

  **Minute 12:** "The brute force counts, for each meeting's start, how many meetings are in progress at that moment and takes the maximum: O(n²), about 10⁸ steps at n = 10⁴. That's borderline. This is an intervals problem, so I'm looking at sorting."

  **Minute 15:** "Plan: sort the start times and the end times separately. Walk the starts; before each start, release every meeting that ended at or before it, using a pointer into the ends. Rooms in use is starts seen minus ends released; the answer is its maximum. O(n log n) for the sorts, O(n) for the sweep."

  **Minute 20:** if there's no code yet: "I'll write the O(n²) count first, so we have a correct answer, then the sweep."

  **Five minutes left, only the sorting done:**

  ```swift
  // Done: starts and ends sorted (O(n log n)).
  // Missing: the sweep. For each start, advance endIndex while
  // ends[endIndex] <= start (a meeting ending at 10 frees its room for one
  // starting at 10), then roomsInUse = startsSeen - endIndex; keep the max.
  // Total: O(n log n) time, O(n) space for the two sorted arrays.
  ```
````

````exercise
id: m46-l06-e6
type: explain
prompt: You're at minute 40. Your solution works for the examples, but a trace just showed it returns the wrong answer when the input is empty. Write what you'd say to the interviewer in the next minute, and explain why you'd say it that way.
code: |
  // Minute 40 of 45. The function is written and passes the statement's
  // examples. A trace of [] returns 1 instead of 0.
rubric:
  - States the bug precisely (input, expected, actual).
  - Proposes the smallest fix (a guard at the top) and says what it does.
  - Mentions retesting the earlier cases after the fix.
  - States the complexity and moves to wrap-up without rewriting anything else.
solution: |
  Something like:

  > "The trace on an empty array returns 1, but it should be 0. The loop never runs and the initial value is returned as is. The fix is a guard at the top, `guard !values.isEmpty else { return 0 }`. Let me add it and recheck the two examples quickly, since the guard shouldn't affect them. … Both still pass. The solution is O(n) time and O(1) space. A follow-up I'd consider is …"

  Why this way: it states input, expected and actual in one sentence, so the interviewer knows you understand the bug and didn't just stumble on it. The fix is the smallest one, which fits the time left. Rechecking the earlier examples shows you know a fix can cause a regression. And you leave the last minutes for complexity and a follow-up, which are part of a complete answer.
````

## Summary

- The course's 45-minute plan: about 5 minutes understanding, 7 exploring, 3 planning, 15 coding, 7 testing, 5 wrapping up and 3 of buffer. Coding is only a third of the time.
- Checkpoints: a brute force with complexity by minute 12, an agreed plan by 15, code on the screen by 20 (otherwise, code the brute force).
- Stuck signals: circling one idea, not knowing why it works, special cases piling up, an unexplained trace, silence. Unstick with tiny examples, the signals tables, a new representation, a simpler version, or the required complexity.
- Ask for specific hints that state what you have and where the gap is, then use the hint out loud.
- With five minutes left, make the main path correct, comment what's missing, trace one case, and state complexity.
- When an approach is wrong, find the counterexample (by hand or with an exhaustive checker), and repair the idea from it instead of starting over.
