---
id: m46-l01
title: The fifteen-step method
description: You learn the course's fifteen-step method for coding problems, grouped into four phases (understand, explore, build, wrap up), and watch it run end to end on a new problem, from restating it to follow-up questions, including a real bug caught by a hand trace. You also see how the steps line up with the sections of the course's challenge cards.
module: m46
order: 1
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m20-l06]
objectives:
  - Name the fifteen steps of the course's method in order and say what each one produces.
  - Apply the method to a new problem from restating it to discussing follow-ups.
  - Use a brute-force solution as a baseline and as a correctness check for the optimized one.
  - Catch a bug with a hand trace before running the code.
  - Map the steps to the sections of a challenge card.
terms:
  - term: Brute force
    definition: The most direct correct solution, usually trying every candidate. Its job is to prove you understand the problem and to give you a baseline to beat and to test against.
  - term: Complement
    definition: The value that, combined with the current one, satisfies the condition. For "sum to a multiple of 60", the complement of a remainder r is (60 − r) mod 60.
  - term: Hand trace
    definition: Running code on paper with a small input, writing down the value of every variable after each step, to check it before (or instead of) running it.
  - term: Follow-up
    definition: A change to the original problem (bigger input, a new constraint, a different output) that an interviewer asks after you solve it, to see how far your solution stretches.
mastery:
  - List the fifteen steps from memory, grouped into four phases.
  - Write the brute force for a new problem and state its time and space before optimizing.
  - Explain which pattern from Modules 16 to 20 a problem matches and why.
  - Trace a solution in a table and find a case it gets wrong.
  - Turn a solved problem into a short trade-off discussion and answer at least one follow-up.
resources: [swift-array, swift-dictionary, swift-book-collection-types, swift-book-basic-operators]
cards:
  - id: m46-l01-c1
    front: What are the four phases of the fifteen-step method?
    back: "Understand (restate, clarify, examples, edge cases), explore (brute force, its complexity, pattern, optimize), build (plan, code, test by hand, debug) and wrap up (final complexity, trade-offs, follow-ups)."
  - id: m46-l01-c2
    front: Why write or describe the brute force before optimizing?
    back: It proves you understood the problem, gives you a complexity to beat, and later serves as a reference to check the fast version against on small inputs.
  - id: m46-l01-c3
    front: "In \"count pairs whose sum is a multiple of 60\", what's the complement of remainder r, and what's the classic bug?"
    back: "(60 − r) % 60. Writing 60 − r alone looks for remainder 60 when r is 0, which never exists, so pairs of exact multiples of 60 are missed."
  - id: m46-l01-c4
    front: Which step usually catches bugs before the interviewer does?
    back: "Step 11, testing by hand: trace the code on the edge cases from step 4, not only on the example from the statement."
  - id: m46-l01-c5
    front: How do the steps map to a challenge card?
    back: "First approach is steps 1–4 and 7; Naive solution is step 5; Problems with the naive solution is step 6; Optimized solution is steps 8–10; Line by line is steps 10–11; Common mistakes is step 12; Variation is step 15."
---

## The idea in one sentence

A coding problem goes better when you run the same fifteen steps every time, so your attention goes to the problem and not to deciding what to do next.

## Why a fixed method

Modules 15 to 20 gave you the tools: Big O, two pointers, sliding windows, hash maps, stacks, recursion, trees, graphs, greedy and dynamic programming. Knowing them isn't the same as using them under a clock with someone watching. What usually goes wrong isn't the algorithm. It's starting to code before understanding the question, testing only the example from the statement, or going silent for ten minutes.

This module is the course's recommendation for how to work a problem out loud. Companies run interviews in different ways, and nothing here describes any particular company's format. The method is meant to hold up whatever the format is, and it's the same structure the course's challenge cards already use.

## The fifteen steps

| # | Step | What you produce |
| --- | --- | --- |
| 1 | Restate the problem | One or two sentences in your own words |
| 2 | Clarify inputs, outputs and constraints | Answers about types, sizes, ranges, duplicates, empty input |
| 3 | Work through examples | The statement's examples, solved by hand, plus one of your own |
| 4 | List edge cases | Empty, one element, all equal, extremes, the case that breaks the obvious idea |
| 5 | Brute force | The simplest correct approach, in words or code |
| 6 | Its complexity | Time and space of the brute force, compared with the input size |
| 7 | Recognize the pattern | Which family the problem belongs to, and why |
| 8 | Optimize | The idea that removes the repeated work |
| 9 | Plan | Pseudocode or a numbered list of what the code will do |
| 10 | Code | The function, with clear names |
| 11 | Test by hand | A trace table on the examples and edge cases |
| 12 | Debug | A fix for whatever the trace found, explained |
| 13 | Analyze complexity | Final time and space, with the reasoning |
| 14 | Discuss trade-offs | What you gave up and when the other choice is better |
| 15 | Follow-ups | How the solution changes if the problem changes |

The steps fall into four phases:

- **Understand (1–4).** You can't solve the wrong problem quickly. These steps are cheap and catch most misunderstandings.
- **Explore (5–8).** Find a correct answer first, measure it, then improve it.
- **Build (9–12).** Write the code from a plan, then prove it works before saying it does.
- **Wrap up (13–15).** Show you understand what you built and its limits.

Fifteen steps sounds like a lot. Most take a sentence or two. On an easy problem, steps 5 to 8 can collapse into "the brute force is O(n²), and a dictionary makes it O(n)". The order matters more than the length.

## The method end to end

Here's a problem that isn't one of the course's challenges:

> A music app builds playlists that should end on a whole minute. Given the durations of the songs in seconds, count the pairs of different songs whose combined duration is a multiple of 60 seconds.

### 1. Restate

"I get an array of positive integers. I count pairs of positions `i < j` where `durations[i] + durations[j]` is divisible by 60. I return the count."

Restating forces you to commit to details the statement left vague: you've just decided that pairs are unordered (`i < j`) and that a song can't pair with itself. Say those out loud; the interviewer will correct you if they're wrong.

### 2. Clarify

The questions and the answers you'd get (lesson 2 covers how to choose the questions):

- How many songs? Up to 6 × 10⁴.
- Range of durations? 1 to 500 seconds. No zeros, no negatives.
- Are pairs counted by position? Yes. Two songs with the same duration are still two different songs.
- Can the count be large? Yes; with 6 × 10⁴ songs all lasting 60 seconds, every pair counts.
- Return type? `Int`.

The last answer is worth a quick check: the most pairs possible is n(n − 1) / 2, about 1.8 × 10⁹ for n = 6 × 10⁴. `Int` is 64-bit on every platform this course targets, so it fits.

### 3. Examples

Work the statement's example by hand. Durations `[30, 20, 150, 100, 40]`:

- 30 + 150 = 180 = 3 × 60 ✓
- 20 + 100 = 120 ✓
- 20 + 40 = 60 ✓
- Every other pair (30 + 20 = 50, 150 + 40 = 190, …) isn't a multiple.

Answer: 3. Then make your own example that tests something the first one didn't: `[60, 60, 60]` has three songs that are each a whole minute, and any two of them sum to 120. Three pairs: 3.

### 4. Edge cases

- Empty array, or one song: 0 pairs.
- Songs that are exact multiples of 60 (like `[60, 60, 60]`): they pair with each other.
- Songs with remainder 30: they pair with each other too, because 30 + 30 = 60.
- Durations above 60, like 150: only the remainder matters.
- A large input where every pair counts: the answer is large, but fits in `Int`.

The second and third bullets are the ones a fast solution is most likely to get wrong. Write them down now, because you'll test them in step 11.

### 5. Brute force

Check every pair:

```swift
func countWholeMinutePairsBruteForce(_ durations: [Int]) -> Int {
    var pairs = 0
    for i in durations.indices {
        for j in (i + 1)..<durations.count where (durations[i] + durations[j]) % 60 == 0 {
            pairs += 1
        }
    }
    return pairs
}

print(countWholeMinutePairsBruteForce([30, 20, 150, 100, 40]))
print(countWholeMinutePairsBruteForce([60, 60, 60]))
print(countWholeMinutePairsBruteForce([]))
```

```output
3
3
0
```

For an empty array, `durations.indices` is empty and the outer loop never runs, so `(i + 1)..<durations.count` is never built. That's worth noticing: with a last index of `i`, `i + 1` is at most `count`, so the inner range is never backwards.

### 6. Its complexity

n(n − 1) / 2 pairs, O(1) each: **O(n²) time, O(1) space.** With n = 6 × 10⁴ that's about 1.8 × 10⁹ checks. Using the rough rule from Module 20 (around 10⁸ simple steps per second), that's tens of seconds. Too slow; the constraint is telling you an O(n) or O(n log n) solution exists.

Say both numbers out loud: "O(n²) time, O(1) space, about two billion checks at the top of the range."

### 7. Recognize the pattern

"Count pairs whose sum satisfies a condition" is the **complement lookup** family from Module 16, lesson 5: for each element, ask how many earlier elements complete it, and keep a count of what you've seen. The [Two Sum](#/challenge/two-sum) challenge belongs to the same family, with "equals a target" as the condition.

The twist here is the condition. "Divisible by 60" only depends on remainders: `(a + b) % 60 == 0` exactly when `a % 60` and `b % 60` add up to 0 or 60.

### 8. Optimize

So for a song with remainder `r`, the songs that complete it have remainder `60 − r`, except when `r` is 0, where the complement is 0 too. Both cases fit in one expression: `(60 − r) % 60`.

Walk the array once. For each song, add the number of earlier songs with the complementary remainder, then record this song's remainder. Counting earlier songs only means each pair is counted once, when its second song is reached, and a song never pairs with itself.

There are only 60 possible remainders, so the counts fit in a 60-element array.

### 9. Plan

```pseudo
Input: durations
Output: number of pairs
countByRemainder ← 60 zeros
pairs ← 0
For each duration in durations
    remainder ← duration mod 60
    needed ← (60 − remainder) mod 60
    pairs ← pairs + countByRemainder[needed]
    countByRemainder[remainder] ← countByRemainder[remainder] + 1
Return pairs
```

The plan takes a minute and pays for itself: the interviewer can confirm the idea before you spend fifteen minutes typing it.

### 10. Code

Here's a first version as someone might really type it, with a dictionary and the complement written the quick way:

```swift
func countWholeMinutePairs(_ durations: [Int]) -> Int {
    var countByRemainder: [Int: Int] = [:]
    var pairs = 0
    for duration in durations {
        let remainder = duration % 60
        pairs += countByRemainder[60 - remainder, default: 0]
        countByRemainder[remainder, default: 0] += 1
    }
    return pairs
}

print(countWholeMinutePairs([30, 20, 150, 100, 40]))
```

```output
3
```

It compiles, and it gets the statement's example right. This is the moment people say "done". Don't.

### 11. Test by hand

Trace it on your own example from step 3, `[60, 60, 60]`, one row per pass. The dictionary column shows the state after the pass:

| duration | remainder | looks up | found | pairs | countByRemainder |
| --- | --- | --- | --- | --- | --- |
| 60 | 0 | 60 | 0 | 0 | [0: 1] |
| 60 | 0 | 60 | 0 | 0 | [0: 2] |
| 60 | 0 | 60 | 0 | 0 | [0: 3] |

The answer should be 3, and the table shows why it's 0: remainders are stored under key 0, but the lookup asks for key 60, which can never exist because a remainder is always between 0 and 59. The code confirms the trace:

```swift
func countWholeMinutePairs(_ durations: [Int]) -> Int {
    var countByRemainder: [Int: Int] = [:]
    var pairs = 0
    for duration in durations {
        let remainder = duration % 60
        pairs += countByRemainder[60 - remainder, default: 0]
        countByRemainder[remainder, default: 0] += 1
    }
    return pairs
}

print(countWholeMinutePairs([60, 60, 60]))
print(countWholeMinutePairs([120, 60, 30, 30]))
```

```output
0
1
```

The second call should be 2 (120 + 60, and 30 + 30) but finds only the 30s.

### 12. Debug

The plan from step 9 already had the right expression, `(60 − remainder) mod 60`; the code dropped the `mod`. That's the usual way bugs get in: the idea was right and the typing wasn't. Fix it, switch to a 60-element array (every remainder is a valid index, and there's no hashing), and check every case from step 4 against the brute force:

```swift
func countWholeMinutePairs(_ durations: [Int]) -> Int {
    var countByRemainder = Array(repeating: 0, count: 60)
    var pairs = 0
    for duration in durations {
        let remainder = duration % 60
        let needed = (60 - remainder) % 60
        pairs += countByRemainder[needed]
        countByRemainder[remainder] += 1
    }
    return pairs
}

func countWholeMinutePairsBruteForce(_ durations: [Int]) -> Int {
    var pairs = 0
    for i in durations.indices {
        for j in (i + 1)..<durations.count where (durations[i] + durations[j]) % 60 == 0 {
            pairs += 1
        }
    }
    return pairs
}

let cases: [[Int]] = [
    [30, 20, 150, 100, 40],
    [60, 60, 60],
    [120, 60, 30, 30],
    [],
    [45],
    [1, 59, 59, 1, 61],
]
for durations in cases {
    let fast = countWholeMinutePairs(durations)
    let slow = countWholeMinutePairsBruteForce(durations)
    print(durations, fast, fast == slow ? "ok" : "MISMATCH, expected \(slow)")
}
```

```output
[30, 20, 150, 100, 40] 3 ok
[60, 60, 60] 3 ok
[120, 60, 30, 30] 2 ok
[] 0 ok
[45] 0 ok
[1, 59, 59, 1, 61] 6 ok
```

Comparing the fast version with the brute force on small inputs is one of the most useful habits in this module. The brute force is too slow for the real input, but it's simple enough to trust, so it's a free oracle for the small ones. In an interview you usually can't run code, so the trace table does the same job by hand.

### 13. Analyze complexity

One pass over n songs, O(1) per song: **O(n) time.** The counts take 60 integers no matter how many songs there are: **O(1) extra space.** Compared with step 6, that's from about 1.8 × 10⁹ checks down to 6 × 10⁴.

### 14. Discuss trade-offs

- **Brute force versus counting.** The brute force is easier to verify and could be extended to return the pairs themselves. The counting version only counts. If the interviewer later wants the actual pairs, the output alone can be O(n²) in size (all songs 60 seconds long), so no algorithm can produce it in O(n).
- **Array versus dictionary.** With a fixed range of 60 keys, an array is simpler and avoids hashing. If the divisor were huge, say 10⁹, a 10⁹-element array would waste memory, and a dictionary holding only the remainders actually seen would be better.
- **Readability.** `let needed = (60 - remainder) % 60` with a one-line comment about the zero case is clearer than a special `if remainder == 0` branch, but both are fine. Pick one and explain it.

### 15. Follow-ups

Expect at least one, and answer from your solution:

- *"Any divisor k instead of 60?"* Replace 60 with k: O(n) time, O(k) space. Ask what happens if k is 0 (division by zero traps, so it's a precondition).
- *"Durations can be negative?"* Swift's `%` keeps the sign of the left operand, so `-10 % 60` is `-10`, not `50`, and `-10` isn't a valid array index. Normalize with `((d % 60) + 60) % 60`. Lesson 5 shows this quirk.
- *"Songs arrive one at a time?"* The solution already works as a stream: keep the array of counts and the running total between arrivals.

## How the steps map to a challenge card

Every challenge in the course is written in this order, so solving one is practice for the method:

| Challenge card section | Steps |
| --- | --- |
| The statement, constraints, "questions for the interviewer", edge cases | 1–4 |
| First approach | 1–4 and 7 |
| Naive solution | 5 |
| Problems with the naive solution | 6 |
| Optimized solution | 8–10 |
| Line by line | 10–11 |
| Common mistakes | 12 |
| Variation and follow-ups | 15 |

When you work a challenge, try to write your own version of each section before you open the reveal.

## Common mistakes

> [!error] Coding before step 4
> The most common way to lose time is writing a full solution to a problem you misread. Steps 1 to 4 take a few minutes and are the cheapest place to find out.

> [!error] Testing only the statement's example
> Statement examples are chosen to explain the problem, not to break your code. In the walkthrough, the buggy version passed the statement's example and failed the case from step 4. Trace at least one edge case.

> [!error] Skipping the brute force because "it's obviously slow"
> Saying it takes ten seconds and shows you understood the problem. It also gives you a fallback: a working O(n²) solution beats an unfinished O(n) one.

> [!error] Stating complexity without saying what n is
> "O(n)" means nothing until you say n is the number of songs. With two inputs, name both: O(n + m), O(n · k).

> [!error] Fixing a bug without explaining it
> Changing code until the example passes looks like guessing. Say what the trace showed, why the line is wrong and what the fix changes, as in step 12.

## Exercises

````exercise
id: m46-l01-e1
type: comprehension
prompt: You've written the brute force for a problem and said it's O(n²) time and O(1) space. According to the method, what comes next?
choices:
  - text: Recognize which pattern the problem belongs to, then optimize.
    correct: true
    why: Steps 7 and 8. The brute force's complexity (step 6) tells you what to beat; the pattern tells you how.
  - text: Start coding the brute force so you have something on the screen.
    correct: false
    why: Coding comes at step 10, after a plan. If time is short, coding the brute force is a fallback, but it isn't the next step.
  - text: Trace the brute force in a table.
    correct: false
    why: Tracing is step 11, for the code you actually write.
  - text: Ask the interviewer whether O(n²) is acceptable and stop there if it is.
    correct: false
    why: Asking is fine, and sometimes the answer is yes. But the method assumes you look for something better unless told otherwise, and the constraints from step 2 usually say whether you need to.
solution: |
  **Recognize the pattern, then optimize** (steps 7 and 8). Step 6 gave you a number to beat. Step 7 asks which family the problem belongs to (complement lookup, two pointers, sliding window, DP…), and step 8 uses that family's idea to remove the repeated work. Only then do you plan (9) and code (10).
````

````exercise
id: m46-l01-e2
type: prediction
prompt: This version computes the complement correctly but stores the remainder before looking it up. Predict the output.
code: |
  func countWholeMinutePairs(_ durations: [Int]) -> Int {
      var countByRemainder = Array(repeating: 0, count: 60)
      var pairs = 0
      for duration in durations {
          let remainder = duration % 60
          countByRemainder[remainder] += 1
          pairs += countByRemainder[(60 - remainder) % 60]
      }
      return pairs
  }

  print(countWholeMinutePairs([20, 40]))
  print(countWholeMinutePairs([60]))
  print(countWholeMinutePairs([30, 30]))
output: |
  1
  1
  3
hints:
  - When a song's remainder is its own complement (0 or 30), what does the lookup find right after the increment?
  - "Trace [30, 30]: after the first song, countByRemainder[30] is 1 and the lookup reads that same slot."
solution: |
  ```output
  1
  1
  3
  ```

  - `[20, 40]`: 20 stores remainder 20 and looks up 40 (0). 40 stores 40 and looks up 20 (1). Total 1, correct.
  - `[60]`: remainder 0 is stored, then the lookup reads slot 0, which is now 1. A single song is paired with itself: 1 instead of 0.
  - `[30, 30]`: the first 30 counts itself (1), the second finds two 30s, itself included (2). Total 3 instead of 1.

  The bug only shows up when a remainder is its own complement, 0 or 30, which is why those were on the edge-case list in step 4. Looking up before storing guarantees you only count earlier songs.
````

````exercise
id: m46-l01-e3
type: fill-in
prompt: Complete the fixed solution. It should print `3` and then `2`.
code: |
  func countWholeMinutePairs(_ durations: [Int]) -> Int {
      var countByRemainder = Array(repeating: 0, count: [[1]])
      var pairs = 0
      for duration in durations {
          let remainder = duration % 60
          let needed = (60 - remainder) [[2]] 60
          pairs += countByRemainder[[[3]]]
          countByRemainder[remainder] += 1
      }
      return pairs
  }

  print(countWholeMinutePairs([60, 60, 60]))
  print(countWholeMinutePairs([120, 60, 30, 30]))
blanks:
  - id: "1"
    answers: ["60"]
  - id: "2"
    answers: ["%"]
  - id: "3"
    answers: ["needed"]
solution: |
  ```swift
  func countWholeMinutePairs(_ durations: [Int]) -> Int {
      var countByRemainder = Array(repeating: 0, count: 60)
      var pairs = 0
      for duration in durations {
          let remainder = duration % 60
          let needed = (60 - remainder) % 60
          pairs += countByRemainder[needed]
          countByRemainder[remainder] += 1
      }
      return pairs
  }

  print(countWholeMinutePairs([60, 60, 60]))
  print(countWholeMinutePairs([120, 60, 30, 30]))
  ```

  ```output
  3
  2
  ```

  Sixty slots cover remainders 0 to 59. The `% 60` maps a remainder of 0 to a complement of 0 instead of 60, and the lookup uses `needed` before the current song is stored, so each pair is counted once and no song pairs with itself.
````

````exercise
id: m46-l01-e4
type: solve
prompt: |
  Apply steps 5 to 13 to a new problem. A shopping app shows "pick any two" deals: given the prices of the items (positive integers, up to 10⁵ items) and a budget, count the pairs of different items whose combined price is **at most** the budget.

  Write `func affordablePairs(_ prices: [Int], budget: Int) -> Int` in O(n log n) time. Before coding, say what the brute force costs and which pattern applies. Expected output for the starter's calls:

  ```output
  4
  0
  6
  0
  ```
starter: |
  func affordablePairs(_ prices: [Int], budget: Int) -> Int {
      // Steps 5–8 first: brute force, its cost, the pattern, the idea.
      return 0
  }

  print(affordablePairs([7, 3, 5, 1], budget: 8))
  print(affordablePairs([10, 20], budget: 5))
  print(affordablePairs([2, 2, 2, 2], budget: 4))
  print(affordablePairs([], budget: 100))
hints:
  - The brute force checks every pair, O(n²). With 10⁵ items that's about 5 × 10⁹ checks.
  - Sort the prices. If prices[left] + prices[right] fits the budget, what do you know about prices[left] paired with every index between left and right?
  - That's converging two pointers (Module 16, lesson 3), counting several pairs per step.
rubric:
  - States the brute force and its O(n²) time before optimizing.
  - Names the pattern (sort, then converging two pointers) and explains why it's correct.
  - When the pair fits, adds right − left and moves left; otherwise moves right.
  - The output matches, including the empty array.
  - "States O(n log n) time for the sort plus O(n) for the walk, and O(n) extra space for the sorted copy."
solution: |
  **Brute force:** check all n(n − 1) / 2 pairs, O(n²) time, O(1) space. Too slow for 10⁵ items.

  **Pattern:** "pairs" plus a comparison with a target, and the order of the input doesn't matter, so sorting is allowed. After sorting, converging two pointers can count many pairs per step.

  **Idea:** with `left` at the cheapest item and `right` at the most expensive, if `prices[left] + prices[right] <= budget`, then `prices[left]` also fits with every item between them, because those are cheaper than `prices[right]`. That's `right - left` pairs at once; move `left` up. If it doesn't fit, the item at `right` is too expensive even with the cheapest remaining item, so drop it.

  ```swift
  func affordablePairs(_ prices: [Int], budget: Int) -> Int {
      let sorted = prices.sorted()
      var left = 0
      var right = sorted.count - 1
      var pairs = 0
      while left < right {
          if sorted[left] + sorted[right] <= budget {
              pairs += right - left
              left += 1
          } else {
              right -= 1
          }
      }
      return pairs
  }

  print(affordablePairs([7, 3, 5, 1], budget: 8))
  print(affordablePairs([10, 20], budget: 5))
  print(affordablePairs([2, 2, 2, 2], budget: 4))
  print(affordablePairs([], budget: 100))
  ```

  ```output
  4
  0
  6
  0
  ```

  For `[7, 3, 5, 1]` sorted to `[1, 3, 5, 7]`: 1 + 7 fits, so 1 pairs with 3, 5 and 7 (3 pairs); then 3 + 7 doesn't fit, drop 7; 3 + 5 fits (1 pair). Total 4.

  **Complexity:** sorting is O(n log n); the walk moves one pointer per pass, so it's O(n). Total **O(n log n) time** and **O(n) extra space** for the sorted copy (`sorted()` returns a new array). If you may modify the input, sorting a `var` copy in place doesn't change the Big O, but it's worth asking (lesson 2).
````

````exercise
id: m46-l01-e5
type: design
prompt: |
  Do steps 1 to 4 only, in writing, for this statement. Don't solve it.

  > A fitness app stores a user's daily step counts. Return the length of the longest stretch of consecutive days in which every day beat the day before.

  Write your restatement, at least four clarifying questions with the answers you'd assume, two examples worked by hand (one from you that tests something tricky), and an edge-case list.
rubric:
  - The restatement says what "stretch" means (contiguous days) and what is returned (a length).
  - Questions cover input size, empty input, whether "beat" means strictly greater, and what a single day counts as.
  - One example includes equal neighbors to test "strictly".
  - Edge cases include an empty array, a single day, all equal, strictly increasing throughout and strictly decreasing throughout.
solution: |
  A possible answer:

  **Restate.** "I get an array of non-negative integers. I return the length of the longest contiguous run where each element is strictly greater than the one before it. A single day is a run of length 1."

  **Clarify** (assumed answers):
  - Size? Up to 10⁵ days, so O(n) or O(n log n).
  - Empty array? Return 0.
  - Does "beat" mean strictly greater? Yes; an equal day breaks the stretch.
  - Does one day count as a stretch of 1? Yes.
  - Contiguous days only, not any increasing subsequence? Contiguous. (This one matters: the subsequence version is a different, harder problem.)

  **Examples.**
  - `[3, 5, 8, 2, 4]`: 3 → 5 → 8 is length 3; 2 → 4 is 2. Answer 3.
  - `[1, 2, 2, 3]`: the equal 2s break it: `[1, 2]` and `[2, 3]`, so 2. This one tests "strictly".

  **Edge cases.** `[]` → 0. `[7]` → 1. `[4, 4, 4]` → 1. `[1, 2, 3, 4]` → 4 (the longest run ends at the last element, a classic place to forget the final update). `[9, 7, 5]` → 1.

  You haven't written a line of code, and you already have six test cases for step 11.
````

````exercise
id: m46-l01-e6
type: find-errors
prompt: A candidate's notes for the playlist problem, typed as comments during an interview. Which statements about them are true?
code: |
  // OK so pairs summing to 60.
  // Dictionary of remainders, look up 60 minus r.
  // Coding it now.
  // ...
  // Done, it returns 3 for the example, so it works.
  // It's O(n).
choices:
  - text: "The candidate skipped clarification and edge cases (steps 2 and 4), which is where the remainder-0 case would have come up."
    correct: true
    why: Remainder 0 and remainder 30 are exactly the edge cases a list would have flagged.
  - text: "\"It returns 3 for the example, so it works\" skips testing by hand on cases that could break it."
    correct: true
    why: The statement's example passes even with the bug. Step 11 is about the cases you chose to break the code.
  - text: "\"It's O(n)\" is incomplete: it doesn't say what n is or mention space."
    correct: true
    why: "Name n (the number of songs) and give space too: O(1) extra with 60 counters, or O(min(n, 60)) with a dictionary."
  - text: The dictionary is the mistake; with a 60-element array the bug disappears.
    correct: false
    why: The bug is the missing % 60 on the complement. An array with index 60 - 0 = 60 would crash instead of returning 0.
rubric:
  - I spotted the missing steps (clarify, edge cases, hand test).
  - I noticed the complexity claim names no n and no space.
  - I explained that the data structure isn't the bug; the complement expression is.
solution: |
  The first three statements are true. The notes go straight from a pattern to code (no steps 2, 4 or 9), call it done after the statement's example (no step 11), and state complexity without naming n or space (step 13 half done).

  The fourth is false. Switching to an array without fixing the complement would make `countByRemainder[60 - 0]` read index 60 of a 60-element array, and the program would stop with `Index out of range`. The structure was never the problem; `60 - remainder` was.
````

## Summary

- The method has fifteen steps in four phases: **understand** (restate, clarify, examples, edge cases), **explore** (brute force, its complexity, pattern, optimize), **build** (plan, code, test by hand, debug) and **wrap up** (complexity, trade-offs, follow-ups).
- Steps are short; the order is the point. Never code before you've restated the problem and listed edge cases.
- The brute force is a baseline to beat, a fallback if time runs out, and an oracle to test the fast version against on small inputs.
- Test by hand on the edge cases you listed, not just the statement's example. In the walkthrough, the bug (`60 - r` instead of `(60 - r) % 60`) passed the example and failed `[60, 60, 60]`.
- State complexity with n named, for time and space, and finish with trade-offs and at least one follow-up.
- The course's challenge cards follow the same order, so every challenge is practice for the method.
