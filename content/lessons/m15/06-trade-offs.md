---
id: m15-l06
title: Trade-offs and explaining complexity in interviews
description: You trade memory for time on purpose, using Two Sum and a remembered Fibonacci as examples, decide when the simple O(n²) solution is the right one, practice saying a solution's complexity out loud the way interviewers expect, and close the module by comparing three solutions to the same problem.
module: m15
order: 6
level: beginner
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m15-l05]
objectives:
  - Describe a time-for-space trade-off and give its cost on both sides in Big O.
  - Decide when a simple O(n²) solution is acceptable, based on how large n can get and how often the code runs.
  - State the time and space complexity of a solution out loud, with n defined, worst or average case named, and the deciding line identified.
  - Compare several solutions to one problem and choose one for a given situation.
terms:
  - term: Trade-off
    definition: Giving up something (usually memory or simplicity) to get something else (usually speed). Every non-trivial choice between algorithms is one.
  - term: Time-for-space trade
    definition: "Using extra memory, like a Set or Dictionary of things already seen, to avoid repeating work. Typical result: O(n²) time with O(1) space becomes O(n) time on average with O(n) space."
  - term: Memoization
    definition: Remembering the results of calls you've already made, usually in a dictionary, so each one is computed once. Module 20 covers it in depth.
  - term: Precomputation
    definition: Doing some work once, up front (sorting, building a Set), so that many later operations are cheaper.
mastery:
  - Explain the brute-force and dictionary approaches to Two Sum in terms of time and space, without code.
  - Say when you'd keep an O(n²) solution, with a concrete bound on n.
  - Deliver a one-paragraph complexity explanation that defines n, names the case, gives time and space, and mentions the alternative.
  - Implement three solutions to one problem and justify which to use in a given scenario.
resources: [swift-dictionary, swift-set, swift-array, swift-book-collection-types]
cards:
  - id: m15-l06-c1
    front: What's the trade-off in Two Sum?
    back: "Brute force checks every pair: O(n²) time, O(1) extra space. A dictionary from value to index finds each complement in O(1) on average: O(n) time on average, O(n) extra space."
  - id: m15-l06-c2
    front: When is an O(n²) solution fine?
    back: When n is small and bounded (7 days, a dozen form fields, 8 players), or the code runs rarely and off the critical path. Ask how big n can get before optimizing.
  - id: m15-l06-c3
    front: What should a spoken complexity answer include?
    back: What n (and m) are, time and space in Big O, which case (worst, or average for hashing), the line or structure that decides it, and the alternative you considered.
  - id: m15-l06-c4
    front: What does memoizing naive Fibonacci change?
    back: Each fib(k) is computed once and stored. Calls drop from exponential (2,692,537 for fib(30)) to 2n − 1 (59), for O(n) extra space in the dictionary and the stack.
---

## The idea in one sentence

Faster algorithms usually cost something, most often memory and sometimes simplicity, and your job is to know both prices and pick the one that fits the problem in front of you.

## Trading memory for time

### Two Sum

The [Two Sum](#/challenge/two-sum) challenge asks for two positions whose values add up to a target. There are two classic approaches, and the challenge is built around the trade between them. Here they are in words; write the code in the challenge.

- **Brute force**: check every pair of positions. That's the triangle loop from lesson 4: n(n − 1) / 2 pairs, **O(n²) time**, and nothing stored besides two indexes, **O(1) extra space**.
- **Remember what you've seen**: walk the list once, and for each value x ask "have I already seen target − x?". If you keep the values you've seen in a dictionary from value to index, each question is a hash lookup, O(1) on average. **O(n) time on average, O(n) extra space** for the dictionary.

With the challenge's limit of 10,000 elements, the brute force checks up to 49,995,000 pairs. The dictionary version does at most 10,000 lookups and 10,000 insertions, and holds up to 10,000 entries. Neither is wrong. The second spends memory to save time, and for this problem the trade is almost always worth it.

### Remembering results: Fibonacci again

Lesson 4's naive `fib` made 2,692,537 calls for fib(30), because it recomputed the same values over and over. Store each result the first time you compute it, and check the store before computing:

```swift
func fib(_ n: Int, memo: inout [Int: Int], calls: inout Int) -> Int {
    calls += 1
    if n <= 1 {
        return n
    }
    if let known = memo[n] {
        return known
    }
    let value = fib(n - 1, memo: &memo, calls: &calls) + fib(n - 2, memo: &memo, calls: &calls)
    memo[n] = value
    return value
}

for n in [10, 30, 90] {
    var memo: [Int: Int] = [:]
    var calls = 0
    let value = fib(n, memo: &memo, calls: &calls)
    print("fib(\(n)) = \(value), \(calls) calls, \(memo.count) stored")
}
```

```output
fib(10) = 55, 19 calls, 9 stored
fib(30) = 832040, 59 calls, 29 stored
fib(90) = 2880067194370816120, 179 calls, 89 stored
```

From 2,692,537 calls to 59. Each value from 2 to n is computed once and stored; every other call finds it in the dictionary or is a base case. That's 2n − 1 calls: **O(n) time** (each dictionary operation O(1) on average), for **O(n) extra space**: n − 1 dictionary entries plus up to n stack frames. This technique is called **memoization**, and Module 20 builds on it.

The loop version from lesson 4 is still better on space: O(n) time and O(1) space, because it only ever needs the last two values. Recognizing that you only need a little of the stored data is often the next step after memoizing.

### Spending time up front

The other common trade is **precomputation**: pay once so that many later operations are cheap. You've already seen two:

- **Sort once, then binary search** (lesson 3): O(n log n) up front, then O(log n) per search.
- **Build a Set once** (lesson 5): O(n) up front and O(n) memory, then O(1) per lookup on average.

Both lose if you only use them once. Both win big when the same data is queried many times.

## When the simple O(n²) is the right answer

Big O describes what happens as n grows. If n can't grow, the growth doesn't matter. Count the actual work for the sizes you'll really see:

| n | Pairs, n(n − 1) / 2 | Typical case |
| --- | --- | --- |
| 7 | 21 | days of the week |
| 20 | 190 | fields in a form |
| 1,000 | 499,500 | items in a cart, if it's a very big cart |
| 100,000 | 4,999,950,000 | posts in a feed, contacts synced from a server |

Comparing every pair of 20 form fields is 190 checks. There's no user-visible difference between that and a `Set`-based version, and the nested loop may be easier to read. At 100,000, the nested loop is close to 5 billion checks and the decision makes itself.

Questions that settle it:

- **How big can n get?** Not how big it is in your test data. Ask what the product allows, or what the API can return.
- **How often does it run?** Once at launch, or on every keystroke, or for every cell as a list scrolls?
- **Who's waiting?** Code on the main thread while the user taps is held to a stricter standard than a background job.
- **What does the faster version cost?** A `Set` needs `Hashable` elements and O(n) memory. Sorting changes the order, or needs a copy. Extra code is extra code to maintain.

If n is small and bounded, write the simple version, and say in a comment why it's fine ("at most 8 players per match"). If n can grow with your users' data, assume it will.

## Saying complexity out loud

In an interview, you're expected to state the complexity of your solution without being asked, and to state it precisely. A good answer has five parts:

1. **Define the variables.** "n is the number of elements" or "n is the number of users and m the number of groups."
2. **Time, with the case.** Worst case by default. For anything built on a `Set` or `Dictionary`, say "on average".
3. **Space, as extra space.** Say whether you count the output, and mention the call stack if you recurse.
4. **Point to the reason.** "The outer loop runs n times and the lookup inside is O(1) on average." This is what shows you derived it rather than remembered it.
5. **Name the trade-off or the alternative.** "The brute force would be O(1) space but O(n²) time." "If the input were sorted, two pointers would give O(1) space."

Here's what that sounds like for Two Sum's dictionary approach:

> "Let n be the length of the array. I walk it once, and for each element I do one dictionary lookup and at most one insertion, both O(1) on average, so time is O(n) on average. In the worst case, with heavy hash collisions, it would degrade, but with Int keys that's not a practical concern. Extra space is O(n) for the dictionary. The brute-force version checks all pairs: O(n²) time with O(1) space. I'm trading memory for time."

And for a recursive function:

> "n is the input number. Each call makes one recursive call with n − 1, and does constant work, so there are n calls: O(n) time. There's no allocation, but the recursion is n frames deep, so it's O(n) space on the call stack. An iterative version would be O(1) space."

Things that cost you points: "it's O(n)" with no n defined; "O(1)" for a hash lookup with no "on average"; forgetting the O(n log n) of a sort you called; calling a nested loop over two different inputs O(n²); and saying "it's fast" instead of a complexity at all.

## Common mistakes

> [!error] Optimizing before asking how big n gets
> A 60-line O(n) version of a 6-line nested loop over 7 items buys nothing. Ask about the bounds first, and say them out loud in an interview: "the constraints say n ≤ 10⁴, so O(n²) is about 5 × 10⁷ pair checks; let me see if I can do better."

> [!error] Quoting time and forgetting space
> "O(n)" for the dictionary version of Two Sum is half the answer. The O(n) extra space is the price, and interviewers want to hear that you know it.

> [!error] Forgetting the cost of a preparation step
> "Binary search, so O(log n)" is wrong if you sorted the input first: the total is O(n log n). Add up every step.

> [!error] Claiming a trade-off that isn't one
> Sorting to use binary search **once** is slower than one linear search. Precomputation pays only when you reuse its result.

## Exercises

````exercise
id: m15-l06-e1
type: comprehension
prompt: Which of these is the best spoken answer for the complexity of a function that checks whether an array of n integers has a duplicate, using a Set?
choices:
  - text: "It's O(1) because Set lookups are O(1)."
    correct: false
    why: That's the cost of one lookup, not of the function, which does up to n of them. And it's O(1) on average.
  - text: "It's O(n)."
    correct: false
    why: No definition of n, no case, no space, and no reason.
  - text: "With n the array's length, I insert each element into a Set once, which is O(1) on average, so O(n) time on average and O(n) extra space for the set. Comparing all pairs instead would be O(n²) time with O(1) space."
    correct: true
    why: It defines n, gives the reason, names the average case, includes space and mentions the alternative.
  - text: "It's very fast because it uses hashing."
    correct: false
    why: "\"Fast\" isn't a complexity, and hashing isn't magic: it has an average and a worst case."
solution: |
  **The third.** It has all five parts: what n is, the time with the right case ("on average", because it's a hash table), the extra space, the reason (one O(1)-average insert per element) and the alternative with its own trade-off. The first answer confuses the cost of one operation with the cost of the function.
````

````exercise
id: m15-l06-e2
type: prediction
prompt: Predict the exact output. The first function is lesson 4's naive Fibonacci; the second remembers results.
code: |
  func naive(_ n: Int, calls: inout Int) -> Int {
      calls += 1
      if n <= 1 {
          return n
      }
      return naive(n - 1, calls: &calls) + naive(n - 2, calls: &calls)
  }

  func remembered(_ n: Int, memo: inout [Int: Int], calls: inout Int) -> Int {
      calls += 1
      if n <= 1 {
          return n
      }
      if let known = memo[n] {
          return known
      }
      let value = remembered(n - 1, memo: &memo, calls: &calls) + remembered(n - 2, memo: &memo, calls: &calls)
      memo[n] = value
      return value
  }

  var naiveCalls = 0
  var memo: [Int: Int] = [:]
  var rememberedCalls = 0
  print(naive(6, calls: &naiveCalls), naiveCalls)
  print(remembered(6, memo: &memo, calls: &rememberedCalls), rememberedCalls, memo.count)
output: |
  8 25
  8 11 5
hints:
  - The naive count for 6 is in lesson 4's exercise 2.
  - "With memoization, the calls are 2n − 1, and the dictionary stores every value from 2 to n."
solution: |
  ```output
  8 25
  8 11 5
  ```

  Both compute fib(6) = 8. The naive version makes 25 calls (lesson 4). The memoized version goes down the left side of the tree once, from 6 to 1 (6 calls), and each of those, except the bottom one, makes a second call that's either a base case or a stored value (5 more): 2n − 1 = 11. The dictionary holds fib(2) through fib(6): 5 entries. The arguments are evaluated before `print` runs, so `naiveCalls` and `rememberedCalls` already have their final values when they're printed.
````

````exercise
id: m15-l06-e3
type: find-errors
prompt: |
  A candidate was asked for "the first value that repeats" in an array of integers: the value whose second occurrence comes earliest. They wrote the code below and said:

  > "It's O(1) because set lookups are O(1). Space doesn't matter here. I sort the array first to make it faster, but that doesn't change anything."

  Which statements about the code and the explanation are true?
code: |
  func firstRepeated(_ values: [Int]) -> Int? {
      let sortedValues = values.sorted()
      var seen = Set<Int>()
      for value in sortedValues {
          if seen.contains(value) {
              return value
          }
          seen.insert(value)
      }
      return nil
  }
choices:
  - text: The loop does up to n lookups and insertions, so it's O(n) time on average, not O(1).
    correct: true
    why: The cost of one lookup isn't the cost of the loop around it, and hash operations are O(1) on average.
  - text: The set uses O(n) extra space, and that's the price of the speedup.
    correct: true
    why: Space always belongs in the answer, especially when it's what you traded.
  - text: The sort is O(n log n), which makes it the dominant cost, and it changes the answer.
    correct: true
    why: "After sorting, the function returns the smallest repeated value, not the one that repeats first in the original order. For [5, 3, 5, 3] it returns 3 instead of 5."
  - text: The explanation never defines n.
    correct: true
    why: Every complexity statement needs its variables defined.
  - text: Set lookups in Swift are O(log n).
    correct: false
    why: Set is a hash table. Apple's documentation lists contains as O(1), and in general hash lookups are O(1) on average.
rubric:
  - I corrected the time to O(n) on average for the loop, and O(n log n) with the sort.
  - I added O(n) extra space for the set.
  - I showed an input where the sort changes the answer.
  - I noticed n wasn't defined.
  - I wrote a fixed version without the sort.
solution: |
  Everything in that explanation needs fixing:

  - **Time**: up to n lookups and insertions, each O(1) on average, is **O(n) on average** for the loop. "O(1)" describes one lookup.
  - **Space**: the set holds up to n values, **O(n)**. That's the trade: comparing every pair would be O(n²) time with O(1) space.
  - **The sort**: O(n log n), more than the rest of the function, so the total becomes O(n log n). Worse, it breaks the result: "first to repeat" is about the original order, and sorting destroys it.
  - **n**: "where n is the length of the array" should come first.

  Remove the sort and walk the original array:

  ```swift
  func firstRepeated(_ values: [Int]) -> Int? {
      var seen = Set<Int>()
      for value in values {
          if !seen.insert(value).inserted {
              return value
          }
      }
      return nil
  }

  print(firstRepeated([5, 3, 5, 3]) ?? -1)
  print(firstRepeated([1, 2, 3]) ?? -1)
  ```

  ```output
  5
  -1
  ```

  A corrected explanation: "With n the length of the array, I walk it once and insert each value into a set. Each insert is O(1) on average, so O(n) time on average and O(n) extra space for the set. Comparing every pair would be O(n²) time with O(1) space."
````

````exercise
id: m15-l06-e4
type: solve
prompt: |
  Write `func mostFrequent(_ values: [Int]) -> Int?` that returns the value that appears most often, or `nil` for an empty array. If several values tie, return the one that appears **first** in the array. It must be O(n) time on average. Then state its extra space, and describe the O(n²) version you avoided.

  ```output
  4
  7
  -1
  ```

  Print `mostFrequent([4, 1, 4, 2, 1]) ?? -1`, `mostFrequent([7, 3, 3, 7]) ?? -1` and `mostFrequent([]) ?? -1`.
starter: |
  func mostFrequent(_ values: [Int]) -> Int? {
      // Your code
      return nil
  }
hints:
  - "Count with a dictionary: counts[value, default: 0] += 1 (Module 7)."
  - "Dictionaries have no order. To break ties by first appearance, walk the original array a second time, not the dictionary."
rubric:
  - The function counts in one pass with a dictionary.
  - Ties go to the value that appears first, by walking the array, not the dictionary.
  - It returns nil for an empty array.
  - I stated O(n) time on average and O(k) extra space, where k is the number of distinct values (at most n).
  - I described the O(n²) alternative (counting each value with a nested loop) and its O(1) extra space.
solution: |
  ```swift
  func mostFrequent(_ values: [Int]) -> Int? {
      var counts: [Int: Int] = [:]
      for value in values {
          counts[value, default: 0] += 1
      }
      var best: Int? = nil
      var bestCount = 0
      for value in values {
          let count = counts[value] ?? 0
          if count > bestCount {
              best = value
              bestCount = count
          }
      }
      return best
  }

  print(mostFrequent([4, 1, 4, 2, 1]) ?? -1)
  print(mostFrequent([7, 3, 3, 7]) ?? -1)
  print(mostFrequent([]) ?? -1)
  ```

  ```output
  4
  7
  -1
  ```

  - **Time**: two passes over n values, each with O(1)-average dictionary operations: **O(n) on average**.
  - **Extra space**: one dictionary entry per distinct value, **O(k)** where k ≤ n is the number of distinct values. In the worst case, all different, that's O(n).
  - **Ties**: the second loop walks the array in order and only replaces `best` on a strictly greater count, so the first value to reach the top count wins. 4 and 1 both appear twice in the first input; 4 comes first. Walking `counts` instead would make the answer depend on the dictionary's order, which isn't stable.
  - **The O(n²) version**: for each value, count its occurrences with an inner loop over the whole array. O(n²) time, O(1) extra space. Fine for 20 values, too slow for 100,000.
````

````exercise
id: m15-l06-e5
type: explain
prompt: |
  Two features need to find pairs. (A) A board game app checks every pair of the players in a match (at most 6) to see who has played each other before. (B) A social app checks every pair of a user's contacts (up to 50,000, synced from the phone) to find duplicates. For each, say whether the nested-loop O(n²) solution is acceptable and why, with numbers.
code: |
  // The same shape for both features: compare every pair once.
  for i in items.indices {
      for j in (i + 1)..<items.count where matches(items[i], items[j]) {
          report(items[i], items[j])
      }
  }
rubric:
  - For A, I computed at most 15 pairs and called the nested loop fine.
  - For B, I computed about 1.25 billion pairs and called the nested loop unacceptable.
  - I proposed an O(n)-on-average alternative for B (a Set or Dictionary keyed on a normalized phone number or email) and mentioned its O(n) memory.
  - I mentioned that the bound on n, not the code's shape, decided each case.
solution: |
  **A: keep the nested loop.** With at most 6 players, n(n − 1) / 2 = 15 pairs. The bound comes from the game's rules, so it can't grow. A `Set`-based version would be harder to read and no faster in any way a player could notice. A comment like `// at most 6 players, so 15 pairs` records the decision.

  **B: don't.** 50,000 contacts is 50,000 × 49,999 / 2 ≈ 1.25 billion pairs, on a phone, probably right after the user granted access and is waiting. And n is set by the user's data, not by your app. Instead, normalize each contact to a key (a phone number in one format, a lowercased email) and group them with a `Dictionary` from key to contacts: one pass, O(n) on average, O(n) memory for the dictionary. Any key with more than one contact is a duplicate group.

  Same algorithmic shape in both features. The decision comes from how large n can get.
````

````exercise
id: m15-l06-e6
type: explain
prompt: |
  The closing problem of the module: **do two lists of IDs share at least one value?** Here are three correct solutions. For each, give the time and extra space in terms of n = `a.count` and m = `b.count`, and say which one you'd use when (1) both lists have about 10 elements, (2) `a` has 1,000,000 elements and `b` has 1,000,000, and (3) you can't use more than O(1) extra memory and `b` is already sorted.
code: |
  // Solution 1: nested loops
  func shareValueNested(_ a: [Int], _ b: [Int]) -> Bool {
      for x in a {
          for y in b where x == y {
              return true
          }
      }
      return false
  }

  // Solution 2: sort b, then binary search for each element of a
  func shareValueSorted(_ a: [Int], _ b: [Int]) -> Bool {
      let sortedB = b.sorted()
      for x in a {
          var low = 0
          var high = sortedB.count - 1
          while low <= high {
              let mid = low + (high - low) / 2
              if sortedB[mid] == x {
                  return true
              } else if sortedB[mid] < x {
                  low = mid + 1
              } else {
                  high = mid - 1
              }
          }
      }
      return false
  }

  // Solution 3: a Set
  func shareValueSet(_ a: [Int], _ b: [Int]) -> Bool {
      let inB = Set(b)
      for x in a where inB.contains(x) {
          return true
      }
      return false
  }
rubric:
  - "Solution 1: O(n · m) time, O(1) extra space."
  - "Solution 2: O(m log m + n log m) time, O(m) extra space for the sorted copy."
  - "Solution 3: O(n + m) time on average, O(m) extra space."
  - I chose solution 1 for tiny lists, solution 3 for large ones, and binary search without the sort (on the already sorted b) for the O(1)-memory case.
  - I tested all three on the same inputs and checked that they agree, including empty lists.
solution: |
  | Solution | Time | Extra space |
  | --- | --- | --- |
  | 1. Nested loops | O(n · m) worst case | O(1) |
  | 2. Sort b, binary search | O(m log m) to sort + O(n log m) to search | O(m) for the sorted copy |
  | 3. Set | O(m) to build + O(n) lookups: O(n + m) on average | O(m) for the set |

  All three agree on the same inputs, including the edge cases:

  ```swift
  func shareValueNested(_ a: [Int], _ b: [Int]) -> Bool {
      for x in a {
          for y in b where x == y {
              return true
          }
      }
      return false
  }

  func shareValueSorted(_ a: [Int], _ b: [Int]) -> Bool {
      let sortedB = b.sorted()
      for x in a {
          var low = 0
          var high = sortedB.count - 1
          while low <= high {
              let mid = low + (high - low) / 2
              if sortedB[mid] == x {
                  return true
              } else if sortedB[mid] < x {
                  low = mid + 1
              } else {
                  high = mid - 1
              }
          }
      }
      return false
  }

  func shareValueSet(_ a: [Int], _ b: [Int]) -> Bool {
      let inB = Set(b)
      for x in a where inB.contains(x) {
          return true
      }
      return false
  }

  let cases: [([Int], [Int])] = [([1, 2, 3], [9, 3]), ([1, 2, 3], [4, 5]), ([], [1]), ([1], []), ([7, 7], [7])]
  for (a, b) in cases {
      print(shareValueNested(a, b), shareValueSorted(a, b), shareValueSet(a, b))
  }
  ```

  ```output
  true true true
  false false false
  false false false
  false false false
  true true true
  ```

  The choices:

  1. **About 10 elements each**: solution 1. At most 100 comparisons, no memory, nothing to get wrong. The other two spend more on setup than they save.
  2. **A million each**: solution 3. The nested loops could do 10¹² comparisons when there's no match. Sorting is about 20 million steps plus a million binary searches of about 20 steps each; the set is about 2 million hash operations on average. Both 2 and 3 are fine in practice; the set is simpler and cheaper, if a million-entry set fits in memory.
  3. **O(1) extra memory, b already sorted**: solution 2 **without the sort**. Binary search directly on `b` gives O(n log m) time and O(1) extra space. Solution 3 is out (O(m) memory), and the sort in solution 2 is both unnecessary and a copy.

  The answer to "which is best?" depends on the sizes, the memory budget and what you know about the input. Saying that, with the numbers, is what the interviewer is listening for.
````

## Summary

- Most speedups are trades. Remembering what you've seen (Two Sum's dictionary, memoized Fibonacci) turns repeated work into O(1)-average lookups, for O(n) memory.
- Precomputation (sorting, building a `Set`) pays once for cheap repeated queries. Used once, it's a loss.
- O(n²) is fine when n is small and bounded by the problem itself. Ask how big n can get, how often the code runs and who's waiting. If n grows with user data, assume it will.
- In an interview, define n, give time with its case ("on average" for hashing), give extra space, point to the line that decides it, and name the alternative.
- There's rarely one best solution. There's the best solution for these sizes, this memory budget and this input.
