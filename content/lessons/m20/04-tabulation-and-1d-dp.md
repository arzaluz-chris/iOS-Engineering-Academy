---
id: m20-l04
title: Tabulation and 1-D dynamic programming
description: You fill a table of subproblem answers bottom-up with a loop instead of recursing down, choose the fill order from the dependencies, shrink the table to a couple of variables when only the last entries matter, and solve three one-dimensional problems this way. A message decoder, ad slots that can't be adjacent, and fewest coins for any coin set, with the coins themselves read back from the table.
module: m20
order: 4
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m20-l03]
objectives:
  - Turn a memoized recursion into a table filled by a loop, choosing the order so every entry's dependencies are filled first.
  - Reduce a 1-D table to O(1) variables when each entry depends on a fixed number of earlier entries.
  - Solve take-or-skip problems with no two adjacent items and reconstruct which items were taken.
  - Compute the fewest coins for any coin set, report an amount that can't be made, and recover the coins used.
terms:
  - term: Tabulation
    definition: Bottom-up dynamic programming. Allocate a table indexed by the state and fill it with loops, smallest subproblems first, so every entry's dependencies are already computed when you reach it.
  - term: Recurrence
    definition: The formula that defines a table entry in terms of other entries, such as best[i] = max(best[i − 1], best[i − 2] + revenue[i − 1]). The same transitions the recursion makes.
  - term: Fill order
    definition: The order in which a table's entries are computed. It must put every entry after all the entries it reads.
  - term: Rolling variables
    definition: Keeping only the last few table entries in variables, because the recurrence never looks further back. Turns O(n) space into O(1).
  - term: Reconstruction
    definition: Recovering the choices behind an optimal value, by walking the table backward or by storing the choice made at each entry.
mastery:
  - Write the bottom-up table for a recursion you memoized, with the right size, base entries and fill order.
  - Replace a 1-D table with two or three rolling variables and keep the update order right.
  - Solve a no-two-adjacent take-or-skip problem and list the chosen positions.
  - Solve fewest coins with a table of optionals and return nil for an amount that can't be made.
  - Explain why the loop order in a coin-combinations count decides whether it counts combinations or sequences.
resources: [swift-array, swift-optional, swift-book-control-flow, swift-book-collection-types]
cards:
  - id: m20-l04-c1
    front: How do you turn a memoized recursion into a table?
    back: Make an array indexed by the state, set the base cases, then loop over the states in an order where each entry's dependencies are already filled, applying the same recurrence. No recursion, no stack depth.
  - id: m20-l04-c2
    front: When can a 1-D table become O(1) space?
    back: When each entry depends only on a fixed number of earlier entries, like the last two. Keep those in variables and shift them each step. You lose the table, so reconstruct the choices before shrinking, or keep a separate record.
  - id: m20-l04-c3
    front: "No two adjacent items, maximize the total: recurrence?"
    back: best[i] = max(best[i − 1], best[i − 2] + value of item i), with best[0] = 0. Either skip item i, or take it and skip the one before.
  - id: m20-l04-c4
    front: Fewest coins for any coin set?
    back: fewest[0] = 0; fewest[a] = 1 + min over coins c ≤ a of fewest[a − c], skipping amounts that can't be made (nil). O(amount × number of coins) time, O(amount) space.
  - id: m20-l04-c5
    front: Counting ways to pay an amount, which loop goes outside?
    back: Coins outside, amounts inside, to count combinations (1+2 and 2+1 once). Amounts outside counts ordered sequences instead. For 5 with coins 1, 2, 5 that's 4 against 9.
---

## The idea in one sentence

Tabulation computes the same answers as memoization, but **in a loop, from the smallest subproblem up**, into an array indexed by the state, so there's no recursion, no stack depth to worry about and no dictionary.

Lesson 3 started from the full problem and recursed down, storing answers as they came back. Here you start from the base cases and build up. Same states, same transitions, opposite direction.

## The decoder, bottom-up

The memoized decoder from lesson 3 had state `i` and the recurrence:

- `ways(n) = 1` (the whole message is read)
- `ways(i) = 0` if `digits[i]` is 0
- otherwise `ways(i) = ways(i + 1)`, plus `ways(i + 2)` if the two digits make 10 to 26

`ways(i)` reads entries **to its right**, so the table has to be filled from right to left:

```swift
func decodingsTable(_ message: String) -> [Int] {
    let digits = message.compactMap { $0.wholeNumberValue }
    let n = digits.count
    var ways = Array(repeating: 0, count: n + 1)
    ways[n] = 1
    for i in stride(from: n - 1, through: 0, by: -1) {
        if digits[i] == 0 {
            continue
        }
        ways[i] = ways[i + 1]
        if i + 1 < n && digits[i] * 10 + digits[i + 1] <= 26 {
            ways[i] += ways[i + 2]
        }
    }
    return ways
}

print(decodingsTable("226"))
print(decodingsTable("11106"))
print(decodingsTable("1212121212121212121212121")[0])
```

```output
[3, 2, 1, 1]
[2, 1, 1, 0, 1, 1]
121393
```

1. **The table:** `ways` has n + 1 entries, one per state, `0...n`. Entry i means "the number of ways to decode the message from position i to the end".
2. **The base case:** `ways[n] = 1`. Everything else starts at 0, which is also the right answer for a position holding a 0, so `continue` leaves it.
3. **The fill order:** `stride(from: n - 1, through: 0, by: -1)` walks from right to left, so `ways[i + 1]` and `ways[i + 2]` are final when `ways[i]` reads them. `stride` with a negative step is how you count down in Swift.
4. **The answer** is `ways[0]`. Returning the whole table here is just to look at it.

Read the "11106" table from the right: position 5 (past the end) is 1; 6 alone is 1; 0 can't start a letter, so 0; 1 at position 2 can only go as "10", which takes `ways[4]` = 1; position 1's "1" gives `ways[2]` = 1 and "11" gives `ways[3]` = 0; position 0 gives `ways[1]` + `ways[2]` = 2. The two decodings are 1 1 10 6 and 11 10 6.

Compared with the memoized version: no recursion at all, so a 200,000-digit message doesn't threaten the stack; every state is computed exactly once, in n steps of O(1); and an `[Int]` replaces the `[Int: Int]`, which is cheaper for every access. The price: **every** state gets computed, even ones the recursion would never reach. For this problem the recursion reaches all of them anyway.

## Only the last two: O(1) space

`ways[i]` reads only `ways[i + 1]` and `ways[i + 2]`. Once you've moved left of a position, nothing reads it again. Keep two variables instead of the table:

```swift
func decodings(_ message: String) -> Int {
    let digits = message.compactMap { $0.wholeNumberValue }
    var next = 1      // ways[i + 1]
    var afterNext = 0 // ways[i + 2]
    for i in stride(from: digits.count - 1, through: 0, by: -1) {
        var current = 0
        if digits[i] != 0 {
            current = next
            if i + 1 < digits.count && digits[i] * 10 + digits[i + 1] <= 26 {
                current += afterNext
            }
        }
        afterNext = next
        next = current
    }
    return next
}

print(decodings("226"), decodings("11106"), decodings("1212121212121212121212121"))
print(decodings(String(repeating: "27", count: 100_000)))
print(decodings(String(repeating: "1", count: 91)))
print(decodings(""))
```

```output
3 2 121393
1
7540113804746346429
1
```

- Before position i, `next` holds `ways[i + 1]` and `afterNext` holds `ways[i + 2]`. At the start, i + 1 is n, so `next` is 1 and `afterNext` is a placeholder that only gets read when there are two digits left.
- **The shift order matters:** `afterNext = next` first, then `next = current`. Swapping the two lines would set both to `current`.
- A 200,000-character message runs fine: O(n) time, O(1) space, no recursion.
- **The counts grow fast.** 91 ones decode in 7,540,113,804,746,346,429 ways, close to `Int.max`. With 92, the count passes `Int.max`, and a debug build stops with an overflow trap (in this course's test container, a crash with `Illegal instruction`). Interview versions of this problem promise the answer fits; real code over long input needs to say what happens when it doesn't.

> [!tip] Shrink last
> Write the full table first, check it against the memoized version, and only then roll it into variables. The table is easy to print and debug; the rolled version isn't. And once the table is gone, you can't read the choices back from it, which the next two problems need.

## Ad slots that can't touch

A video feed has slots between posts. Each slot has an expected revenue if it shows an ad, but two adjacent slots can't both show one. Which slots maximize revenue?

For the first i slots, the last slot (index i − 1) is either **skipped**, leaving the best for the first i − 1, or **taken**, which forbids slot i − 2 and leaves the best for the first i − 2:

`best[i] = max(best[i − 1], revenue[i − 1] + best[i − 2])`

```swift
func bestAdPlan(_ revenue: [Int]) -> (total: Int, slots: [Int]) {
    let n = revenue.count
    // best[i]: the most revenue from the first i slots.
    var best = Array(repeating: 0, count: n + 1)
    for i in 0..<n {
        let skip = best[i]
        let take = revenue[i] + (i >= 1 ? best[i - 1] : 0)
        best[i + 1] = max(skip, take)
    }
    print("table:", best)

    var slots: [Int] = []
    var i = n
    while i >= 1 {
        if best[i] == best[i - 1] {
            i -= 1
        } else {
            slots.append(i - 1)
            i -= 2
        }
    }
    return (best[n], slots.reversed())
}

let plan = bestAdPlan([30, 10, 50, 40, 20, 60])
print(plan.total, plan.slots)
print(bestAdPlan([]).total)
```

```output
table: [0, 30, 30, 80, 80, 100, 140]
140 [0, 2, 5]
table: [0]
0
```

- The table has n + 1 entries so that "the first 0 slots" (`best[0] = 0`) is a real entry. The loop variable `i` is a slot index, and it fills `best[i + 1]`; the shift by one is the price of the empty prefix, and the most common source of off-by-one bugs in tabulation.
- `best` reads to the left, so the loop runs left to right.
- **Reconstruction** walks the table backward. If `best[i]` equals `best[i - 1]`, skipping slot i − 1 achieves the best, so step back one. Otherwise slot i − 1 must have been taken: record it and jump back two, past its forbidden neighbor. When skip and take tie, this prefers skip; both lead to an optimal plan.
- Slots 0, 2 and 5: 30 + 50 + 60 = 140. Taking every other slot gives 100 (even indexes) or 110 (odd). The table found a plan that isn't a simple pattern.

The rolled version keeps two variables, as with the decoder, at the cost of losing the reconstruction. Exercise 2 traces another table.

## Fewest coins, for any coin set

Lesson 1 left this open: greedy coin change is wrong for coins like 1, 3 and 4, and the exhaustive search was exponential. The state is the amount. To make `a` with the fewest coins, some coin c is the last one used, and the rest is the best way to make `a − c`. Try every c:

`fewest[a] = 1 + min over coins c ≤ a of fewest[a − c]`, with `fewest[0] = 0`

Some amounts can't be made at all, so each entry is an `Int?`: `nil` means "impossible". That's safer than a big sentinel like `Int.max`, which overflows the moment you add 1 to it.

```swift
func fewestCoins(_ amount: Int, coins: [Int]) -> [Int]? {
    // fewest[a]: the fewest coins that make a, or nil if a can't be made.
    var fewest: [Int?] = Array(repeating: nil, count: amount + 1)
    var lastCoin = Array(repeating: 0, count: amount + 1)
    fewest[0] = 0
    if amount > 0 {
        for a in 1...amount {
            for coin in coins where coin <= a {
                if let before = fewest[a - coin], before + 1 < (fewest[a] ?? Int.max) {
                    fewest[a] = before + 1
                    lastCoin[a] = coin
                }
            }
        }
    }
    guard fewest[amount] != nil else { return nil }
    var used: [Int] = []
    var a = amount
    while a > 0 {
        used.append(lastCoin[a])
        a -= lastCoin[a]
    }
    return used
}

print(fewestCoins(10, coins: [1, 3, 4]) ?? [])
print(fewestCoins(9, coins: [5, 3]) ?? [])
print(fewestCoins(7, coins: [5, 3]) == nil)
print(fewestCoins(68, coins: [25, 10, 5, 1]) ?? [])
print(fewestCoins(0, coins: [2]) ?? [])
```

```output
[3, 3, 4]
[3, 3, 3]
true
[25, 25, 10, 5, 1, 1, 1]
[]
```

- `if let before = fewest[a - coin]` skips coins whose remainder can't be made.
- `fewest[a] ?? Int.max` treats "nothing found yet" as infinitely bad for the comparison only. `before + 1` never touches `Int.max`, so nothing overflows.
- `lastCoin[a]` records **the choice** that produced the best value. Reconstruction follows it: take `lastCoin[a]`, subtract, repeat. Storing the choice is the other way to reconstruct, and it's simpler than re-deriving the choice from the values when there are many options per entry.
- Lesson 1's failures are fixed: 10 with 1, 3, 4 takes three coins (greedy took four), 9 with 5 and 3 is 3 + 3 + 3, and 7 with 5 and 3 is correctly reported impossible.
- `if amount > 0` guards the range: `1...0` would crash, since a closed range needs its lower bound at most its upper bound.

Here's the table for 1, 3, 4, with `-` for impossible amounts and with 5 and 3 alongside:

| amount | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| coins 1, 3, 4 | 0 | 1 | 2 | 1 | 1 | 2 | 2 | 2 | 2 | 3 | 3 |
| coins 5, 3 | 0 | - | - | 1 | - | 1 | 2 | - | 2 | 3 | 2 |

**Cost:** amount + 1 entries, each trying k coins: **O(amount × k) time, O(amount) space.** That's pseudo-polynomial: linear in the amount's value, not in the number of digits used to write it. Fine for 10,000 cents, hopeless for an amount of 10¹⁵.

## Common mistakes

> [!error] Filling in the wrong direction
> If `ways[i]` reads `ways[i + 1]`, a left-to-right loop reads entries that are still 0 and silently returns wrong counts. Before writing the loop, write the recurrence and look at which side its reads are on.

> [!error] Using Int.max as "impossible" and adding to it
> `fewest[a - coin] + 1` with `Int.max` stored for unreachable amounts overflows and the program traps. Use `Int?` and `if let`, or a sentinel that can't overflow, like `amount + 1`: every coin is worth at least 1, so no real answer uses more than `amount` coins.

> [!error] Off by one between the table and the input
> With an empty-prefix entry, `best[i + 1]` describes `revenue[i]`. Mixing the two indexes is the classic tabulation bug. Write a comment saying what entry i means, and check the smallest cases (0 and 1 items) by hand.

> [!error] Rolling variables updated in the wrong order
> `next = current` before `afterNext = next` copies the new value into both. Update the oldest variable first.

> [!error] Shrinking to O(1) and then needing the choices
> The rolled versions only know the final value. If the problem asks which slots, which coins or which steps, keep the table (or a choice array) at least until you've reconstructed the answer.

## Exercises

````exercise
id: m20-l04-e1
type: comprehension
prompt: |
  A table's recurrence is `cost[i] = min(cost[i + 1], cost[i + 3]) + fee[i]`, with `cost[n]`, `cost[n + 1]` and `cost[n + 2]` set to 0. Which fill order is correct?
choices:
  - text: "From i = n − 1 down to 0."
    correct: true
    why: "cost[i] reads entries with larger indexes, so those have to be computed first."
  - text: "From i = 0 up to n − 1."
    correct: false
    why: "When the loop computes cost[0], cost[1] and cost[3] haven't been computed yet."
  - text: "Either order works, since every entry is computed eventually."
    correct: false
    why: "A tabulated entry is computed once, from whatever its dependencies hold at that moment."
  - text: "Recursion is required, because entries depend on later entries."
    correct: false
    why: "Later entries are only a problem for a left-to-right loop. A right-to-left loop handles them."
solution: |
  **Right to left.** The fill order comes straight from the recurrence: every entry it reads must already be final. Reads at `i + 1` and `i + 3` point right, so the loop goes left. The three entries past the end hold the base cases, which is also why the table needs n + 3 entries.
````

````exercise
id: m20-l04-e2
type: prediction
prompt: Predict the exact output.
code: |
  func bestTotal(_ revenue: [Int]) -> [Int] {
      var best = Array(repeating: 0, count: revenue.count + 1)
      for i in 0..<revenue.count {
          let skip = best[i]
          let take = revenue[i] + (i >= 1 ? best[i - 1] : 0)
          best[i + 1] = max(skip, take)
      }
      return best
  }

  print(bestTotal([20, 50, 30, 10, 40]))
output: |
  [0, 20, 50, 50, 60, 90]
hints:
  - "best[1] is the first slot alone. best[2] is the better of slot 0 or slot 1."
  - "best[3]: skip slot 2 (50) or take it, 30 + best[1] (20 + 30 = 50)."
solution: |
  ```output
  [0, 20, 50, 50, 60, 90]
  ```

  - `best[1]` = max(0, 20 + 0) = 20.
  - `best[2]` = max(20, 50 + 0) = 50.
  - `best[3]` = max(50, 30 + 20) = 50: a tie.
  - `best[4]` = max(50, 10 + 50) = 60.
  - `best[5]` = max(60, 40 + 50) = 90.

  The 90 is slots 1 and 4 (50 + 40). Walking back: `best[5]` ≠ `best[4]`, so slot 4 was taken; jump to `best[3]`, which equals `best[2]`, so step to `best[2]`, which differs from `best[1]`: slot 1 was taken.
````

````exercise
id: m20-l04-e3
type: fill-in
prompt: Complete the fewest-coins table. `nil` means the amount can't be made.
code: |
  var fewest: [Int?] = Array(repeating: nil, count: amount + 1)
  fewest[0] = [[1]]
  for a in 1...amount {
      for coin in coins where coin <= a {
          if let before = fewest[[[2]]], before + 1 < (fewest[a] ?? Int.max) {
              fewest[a] = [[3]]
          }
      }
  }
blanks:
  - id: "1"
    answers: ["0"]
  - id: "2"
    answers: ["a - coin", "a-coin"]
  - id: "3"
    answers: ["before + 1", "before+1", "1 + before"]
solution: |
  - `0`: zero coins make the amount 0. That's the base case every other entry builds on.
  - `a - coin`: if `coin` is the last coin, the rest is the best way to make `a - coin`.
  - `before + 1`: that rest plus this coin.

  ```swift
  func fewestCoinCount(_ amount: Int, coins: [Int]) -> Int? {
      var fewest: [Int?] = Array(repeating: nil, count: amount + 1)
      fewest[0] = 0
      for a in 1...amount {
          for coin in coins where coin <= a {
              if let before = fewest[a - coin], before + 1 < (fewest[a] ?? Int.max) {
                  fewest[a] = before + 1
              }
          }
      }
      return fewest[amount]
  }

  print(fewestCoinCount(6, coins: [1, 3, 4]) ?? -1)
  print(fewestCoinCount(11, coins: [1, 5, 6, 9]) ?? -1)
  print(fewestCoinCount(7, coins: [5, 3]) ?? -1)
  ```

  ```output
  2
  2
  -1
  ```

  6 = 3 + 3 and 11 = 5 + 6, where greedy took 3 coins each. This version needs `amount` ≥ 1 because of `1...amount`; the lesson's version guards it.
````

````exercise
id: m20-l04-e4
type: find-errors
prompt: |
  This should count the ways to pay `amount` with the given coins, where 1 + 2 and 2 + 1 are the same way. For 5 with coins 1, 2 and 5 it returns 9; the answer is 4. Which statements are true?
code: |
  func waysToPay(_ amount: Int, coins: [Int]) -> Int {
      var ways = Array(repeating: 0, count: amount + 1)
      ways[0] = 1
      for a in stride(from: 1, through: amount, by: 1) {
          for coin in coins where coin <= a {
              ways[a] += ways[a - coin]
          }
      }
      return ways[amount]
  }
choices:
  - text: "With amounts in the outer loop, every order of the same coins is counted separately, so it counts sequences, not combinations."
    correct: true
    why: "ways[3] gets 1+2 (last coin 2) and 2+1 (last coin 1) as two different ways."
  - text: "Putting the coins in the outer loop and the amounts inside fixes it."
    correct: true
    why: "Then every way is built with coins in the order they appear in coins, so each combination is counted once."
  - text: "ways[0] should be 0, because paying 0 needs no coins."
    correct: false
    why: "There's exactly one way to pay 0: use no coins. With 0, every entry would be 0."
  - text: "The where clause makes it skip valid ways."
    correct: false
    why: "A coin bigger than a can't be the last coin of a; skipping it is right and avoids a negative index."
rubric:
  - I explained that the amount-outer loop counts ordered sequences.
  - I gave the coin-outer fix and why it counts each combination once.
  - I defended ways[0] = 1 and the where clause.
solution: |
  The loops decide what's being counted. Amount outside: `ways[a]` sums over "the last coin is c" for every c, so the same coins in different orders are different ways. That's the right recurrence for "how many sequences of steps", the climbing-stairs kind of question. Coin outside: when the loop over coin c runs, the table only contains ways built from the coins before it, so c is always added after them, and each multiset of coins is counted in exactly one order.

  ```swift
  func waysToPay(_ amount: Int, coins: [Int]) -> Int {
      var ways = Array(repeating: 0, count: amount + 1)
      ways[0] = 1
      for coin in coins {
          for a in stride(from: coin, through: amount, by: 1) {
              ways[a] += ways[a - coin]
          }
      }
      return ways[amount]
  }

  print(waysToPay(5, coins: [1, 2, 5]))
  print(waysToPay(100, coins: [1, 5, 10, 25]))
  ```

  ```output
  4
  242
  ```

  The four ways for 5: 5; 2 + 2 + 1; 2 + 1 + 1 + 1; 1 + 1 + 1 + 1 + 1. There are 242 ways to make change for a dollar with US coins below the half-dollar; the buggy order reports 8,577,828,731,901 for the same input, because it counts every ordering.
````

````exercise
id: m20-l04-e5
type: solve
prompt: |
  A platform game charges a fee to land on each platform. You start on the ground, before platform 0, and each jump moves you 1 or 2 platforms forward. You finish when you jump past the last platform. Write `func cheapestClimb(_ fees: [Int]) -> Int` that returns the lowest total fee. Use O(n) time and O(1) extra space.

  Print:

  ```output
  15
  6
  0
  0
  ```

  for `[10, 15, 20]`, `[1, 100, 1, 1, 1, 100, 1, 1, 100, 1]`, `[5]` and `[]`.
starter: |
  func cheapestClimb(_ fees: [Int]) -> Int {
      // cost[i]: the lowest total to stand on platform i.
      // You can reach the top from the last platform or the one before it.
      return 0
  }
hints:
  - "To stand on platform i, you came from i − 1 or i − 2 (or from the ground for platforms 0 and 1). cost[i] = fees[i] + min(cost[i − 1], cost[i − 2])."
  - "Treat the ground as two virtual entries with cost 0, before platform 0. The top is reached from either of the last two entries."
  - "Only two previous values are ever read: roll them into variables."
rubric:
  - The recurrence is cost[i] = fees[i] + min of the previous two, with the ground as cost 0.
  - The answer is the min of the last two costs, since the top can be reached from either.
  - It uses O(1) extra space with the variables shifted in the right order.
  - The empty and single-platform cases are handled.
solution: |
  ```swift
  func cheapestClimb(_ fees: [Int]) -> Int {
      var twoBack = 0 // cost of the position two before the current platform
      var oneBack = 0 // cost of the position just before it
      for fee in fees {
          let current = fee + min(oneBack, twoBack)
          twoBack = oneBack
          oneBack = current
      }
      return min(oneBack, twoBack)
  }

  print(cheapestClimb([10, 15, 20]))
  print(cheapestClimb([1, 100, 1, 1, 1, 100, 1, 1, 100, 1]))
  print(cheapestClimb([5]))
  print(cheapestClimb([]))
  ```

  ```output
  15
  6
  0
  0
  ```

  **State:** the platform you stand on. **Transition:** you came from one or two platforms back. Starting both variables at 0 models the ground: platform 0 and platform 1 can both be reached from it for free. The top is reachable from the last platform or the one before it, so the answer is the smaller of the two final values. With `[10, 15, 20]`, land only on 15 and jump past. With `[5]`, jump from the ground over it: 0. Each step reads only the previous two costs, so two variables are enough; `twoBack` is updated before `oneBack` is overwritten.
````

````exercise
id: m20-l04-e6
type: refactor
prompt: |
  A progress bar fills `n` segments, advancing 1, 2 or 3 segments per tick. This memoized function counts the different tick sequences that fill it exactly. Rewrite it bottom-up with O(1) extra space, no recursion and no dictionary. Print the counts for 0, 4 and 10 segments.
code: |
  func fillSequences(_ n: Int) -> Int {
      var memo: [Int: Int] = [:]
      func count(_ remaining: Int) -> Int {
          if remaining == 0 { return 1 }
          if remaining < 0 { return 0 }
          if let known = memo[remaining] { return known }
          let total = count(remaining - 1) + count(remaining - 2) + count(remaining - 3)
          memo[remaining] = total
          return total
      }
      return count(n)
  }
rubric:
  - The new version uses three rolling variables for the last three counts.
  - The base cases (1 way to fill 0, nothing for negatives) are encoded in the starting values.
  - The variables shift oldest first.
  - The outputs for 0, 4 and 10 match the memoized version.
solution: |
  ```swift
  func fillSequences(_ n: Int) -> Int {
      var threeBack = 0 // count(i − 3)
      var twoBack = 0   // count(i − 2)
      var oneBack = 1   // count(i − 1); starts as count(0) = 1
      if n == 0 {
          return 1
      }
      for _ in 1...n {
          let current = oneBack + twoBack + threeBack
          threeBack = twoBack
          twoBack = oneBack
          oneBack = current
      }
      return oneBack
  }

  print(fillSequences(0), fillSequences(4), fillSequences(10))
  ```

  ```output
  1 7 274
  ```

  `count(i)` reads `count(i − 1)`, `count(i − 2)` and `count(i − 3)`, so the loop goes upward from 1 and keeps three values. Before the first step they stand for count(0) = 1 and the two negative amounts, which are 0. Each step computes the next count and shifts the window, oldest first. For 4 segments the seven sequences are 1111, 112, 121, 211, 22, 13 and 31. Order matters here (1 then 3 is a different animation from 3 then 1), which is why this is the amount-outside kind of count from exercise 4.
````

## Summary

- **Tabulation** fills a table indexed by the state with loops, base cases first, in an order where every entry's reads are already final. Same recurrence as the memoized recursion, no stack depth.
- Get the order from the recurrence: reads to the right mean a right-to-left loop, and vice versa.
- When an entry reads only the last few entries, **roll** them into variables for O(1) space. Update oldest first, and reconstruct before you throw the table away.
- **No two adjacent:** `best[i] = max(best[i − 1], value + best[i − 2])`. Reconstruct by walking back: equal to the previous entry means skipped.
- **Fewest coins:** `fewest[a] = 1 + min fewest[a − c]`, with `Int?` for impossible amounts and a `lastCoin` array for the coins. O(amount × k). It fixes every case where greedy failed.
- In counting problems, the loop order decides whether you count combinations (items outside) or sequences (amounts outside).
