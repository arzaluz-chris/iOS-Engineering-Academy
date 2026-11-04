---
id: m20-l01
title: Greedy algorithms
description: You build an answer one locally best choice at a time and never go back, see coin change work with US coins and fail with coins of 1, 3 and 4 by running the greedy version next to an exhaustive search, and justify a greedy rule with an exchange argument, using shortest-job-first scheduling as the example.
module: m20
order: 1
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m19-l06]
objectives:
  - Describe a greedy algorithm as a sequence of locally best choices that are never undone.
  - Break a wrong greedy rule with a small counterexample, and check a greedy rule against an exhaustive search on every small input.
  - Justify a greedy rule with an exchange argument.
  - Name the two properties a problem needs for greedy to be correct.
terms:
  - term: Greedy algorithm
    definition: An algorithm that builds its answer step by step, at each step taking the choice that looks best right now, and never reconsidering a choice it already made.
  - term: Greedy-choice property
    definition: A problem has it when some optimal answer starts with the greedy choice. Then making that choice can't cost you the best answer.
  - term: Optimal substructure
    definition: An optimal answer to the whole problem contains optimal answers to the smaller problems left after the first choice. Both greedy algorithms and dynamic programming need it.
  - term: Exchange argument
    definition: A proof technique for greedy rules. Take any optimal answer that differs from the greedy one, swap one of its choices for the greedy choice, and show the result is no worse. Repeat until it is the greedy answer.
  - term: Counterexample
    definition: One concrete input on which a rule gives a wrong answer. A single counterexample is enough to reject a greedy rule.
mastery:
  - Write the greedy coin-change function and give an input where it uses more coins than needed.
  - Compare a greedy function against an exhaustive search over every small input and report where they differ.
  - Prove that running the shortest job first minimizes total waiting time, using an adjacent swap.
  - Say, for a proposed greedy rule, what you'd do before trusting it in an interview.
resources: [swift-array-sorted-by, swift-array, swift-book-closures, swift-book-control-flow]
cards:
  - id: m20-l01-c1
    front: What makes an algorithm greedy?
    back: At each step it takes the choice that looks best right now and never goes back to change it. Correct only when the problem guarantees that the locally best choice is part of some optimal answer.
  - id: m20-l01-c2
    front: Greedy coin change with coins 1, 3 and 4 for the amount 6?
    back: Greedy takes 4 + 1 + 1, three coins. The best is 3 + 3, two coins. With US coins (25, 10, 5, 1) greedy is optimal; for an arbitrary coin set it isn't.
  - id: m20-l01-c3
    front: How does an exchange argument prove a greedy rule?
    back: Take an optimal answer that doesn't follow the rule. Swap one of its choices for the greedy choice and show the result is no worse. Repeating the swap turns it into the greedy answer without ever getting worse, so the greedy answer is optimal too.
  - id: m20-l01-c4
    front: Jobs of different lengths run one at a time. Which order minimizes the total time everyone waits?
    back: Shortest first. If a longer job a runs just before a shorter job b, swapping them changes the total by b − a, which is negative, so any order with such a pair can be improved.
  - id: m20-l01-c5
    front: How do you check a greedy idea before trusting it?
    back: Try to break it with small hand-made inputs, then compare it against an exhaustive search on every small input. If they never differ, try to prove it with an exchange argument.
---

## The idea in one sentence

A greedy algorithm builds the answer **one locally best choice at a time and never goes back**, and it's correct only when you can show that the locally best choice never costs you the best overall answer.

Backtracking in Module 18 tried every choice and undid the ones that didn't work out. Greedy makes one choice per step and keeps it. That's why it's fast, and why it's often wrong.

## Making change

A cashier gives 68 cents in as few coins as possible. Nobody computes anything clever; they take the biggest coin that fits, again and again:

```swift
func greedyChange(_ amount: Int, coins: [Int]) -> [Int] {
    var remaining = amount
    var used: [Int] = []
    for coin in coins.sorted(by: >) {
        while coin <= remaining {
            used.append(coin)
            remaining -= coin
        }
    }
    return used
}

print(greedyChange(68, coins: [25, 10, 5, 1]))
print(greedyChange(6, coins: [1, 3, 4]))
```

```output
[25, 25, 10, 5, 1, 1, 1]
[4, 1, 1]
```

- `coins.sorted(by: >)` puts the biggest coin first, so the loop tries coins in the order the rule needs.
- The `while` takes the current coin as many times as it fits. That's the **greedy choice**: the coin that makes the most progress right now.
- Once the loop moves past a coin, it never comes back to it, and a coin already in `used` is never taken out.

The time is O(k log k) for sorting k coin values, plus one step per coin handed out. (Dividing `remaining / coin` would hand out each coin value in one step.)

For 68 cents with US coins, seven coins is the best possible. For 6 with coins of 1, 3 and 4, the greedy answer takes three coins, but **3 + 3** takes two. Taking the 4 looked best and ruined the rest.

## Checking a greedy rule against a search

One counterexample is enough to reject a rule. Not finding one proves nothing, but you can make "not finding one" much more convincing by checking every small input against a slow method that's certainly right. Here, that's an exhaustive search with the backtracking template from Module 18, keeping the shortest combination it finds:

```swift
func greedyChange(_ amount: Int, coins: [Int]) -> [Int] {
    var remaining = amount
    var used: [Int] = []
    for coin in coins.sorted(by: >) {
        while coin <= remaining {
            used.append(coin)
            remaining -= coin
        }
    }
    return used
}

// Tries every combination of coins, largest first, and keeps the shortest.
func fewestCoins(_ amount: Int, coins: [Int]) -> [Int] {
    let sorted = coins.sorted(by: >)
    var best: [Int] = []
    var bestCount = Int.max
    var current: [Int] = []

    func explore(from start: Int, remaining: Int) {
        if remaining == 0 {
            if current.count < bestCount {
                bestCount = current.count
                best = current
            }
            return
        }
        for i in start..<sorted.count where sorted[i] <= remaining {
            current.append(sorted[i])
            explore(from: i, remaining: remaining - sorted[i])
            current.removeLast()
        }
    }

    explore(from: 0, remaining: amount)
    return best
}

for coins in [[25, 10, 5, 1], [1, 3, 4]] {
    var mismatches: [Int] = []
    for amount in 1...99 {
        if greedyChange(amount, coins: coins).count != fewestCoins(amount, coins: coins).count {
            mismatches.append(amount)
        }
    }
    print(coins, "greedy loses at", mismatches.count, "amounts:", mismatches.prefix(5))
}
print(greedyChange(10, coins: [1, 3, 4]), fewestCoins(10, coins: [1, 3, 4]))
```

```output
[25, 10, 5, 1] greedy loses at 0 amounts: []
[1, 3, 4] greedy loses at 24 amounts: [6, 10, 14, 18, 22]
[4, 4, 1, 1] [4, 3, 3]
```

- `fewestCoins` explores every multiset of coins that adds up to the amount (recursing with `i`, not `i + 1`, because a coin can be reused, as in Module 18's pruning lesson) and keeps the shortest. It's exponential, which is fine for amounts under 100.
- With US coins, greedy matches the search on every amount from 1 to 99. Coin systems where greedy is always optimal are called **canonical**, and US coins are one. Checking 99 amounts isn't a proof, but it's the kind of evidence you collect before you try to prove one.
- With 1, 3 and 4, greedy loses on 24 of the 99 amounts. On 10 it takes four coins where three are enough.

So "take the biggest coin" isn't a coin-change algorithm. It's an algorithm for some coin sets. Lesson 4 solves fewest coins for any coin set, in O(amount × k), with dynamic programming.

> [!tip] Keep the brute force around
> A slow, obviously correct function is the best test oracle you'll ever have. Writing one first, then the fast version, then comparing them on every small input is how you catch a greedy rule that's almost right. You'll use the same trick to check the dynamic programming solutions in the rest of this module.

## When greedy works

A greedy algorithm is correct when the problem has two properties:

1. **Greedy-choice property.** Some optimal answer starts with the greedy choice. Taking it can't lock you out of the best answer.
2. **Optimal substructure.** After the first choice, what's left is a smaller problem of the same kind, and an optimal answer to the whole thing contains an optimal answer to that smaller problem.

Coin change with 1, 3 and 4 has optimal substructure: the best way to make 6 that starts with a 3 contains the best way to make the remaining 3. It fails the greedy-choice property: no optimal answer for 6 starts with the 4. That's exactly the gap dynamic programming fills, by trying every first choice and remembering the subproblems. Lesson 3 starts there.

The tool for showing the greedy-choice property is the exchange argument.

## Proving a greedy rule: the exchange argument

A build server runs one job at a time. Each developer waits until their own job finishes. The jobs are already queued; you choose the order. To minimize the **total** waiting time, which order is best?

```swift
func totalWait(_ durations: [Int]) -> Int {
    var clock = 0
    var total = 0
    for duration in durations {
        clock += duration
        total += clock
    }
    return total
}

func bestOrderByBruteForce(_ durations: [Int]) -> Int {
    var best = Int.max
    var current: [Int] = []
    var used = Array(repeating: false, count: durations.count)

    func explore() {
        if current.count == durations.count {
            best = min(best, totalWait(current))
            return
        }
        for i in 0..<durations.count where !used[i] {
            used[i] = true
            current.append(durations[i])
            explore()
            current.removeLast()
            used[i] = false
        }
    }

    explore()
    return best
}

let jobs = [8, 3, 12, 1, 5, 7]
print("as given:", totalWait(jobs))
print("shortest first:", totalWait(jobs.sorted()))
print("longest first:", totalWait(jobs.sorted(by: >)))
print("best of 720 orders:", bestOrderByBruteForce(jobs))
```

```output
as given: 131
shortest first: 90
longest first: 162
best of 720 orders: 90
```

- `clock` is when the current job finishes; adding it to `total` is that developer's wait.
- `bestOrderByBruteForce` is Module 18's permutations template: it tries all 6! = 720 orders.
- Shortest first matches the best of all 720. The greedy rule is "run the shortest remaining job next", and the whole algorithm is one sort: O(n log n).

Matching on one input isn't a proof. Here's the proof, as an exchange argument:

1. **Take any order that isn't sorted.** Somewhere in it, a job of length a runs immediately before a job of length b, with a > b.
2. **Swap just those two.** Every job before them finishes at the same time as before. Every job after them does too, because the pair still takes a + b in total. Only the two of them change.
3. **Compare.** Say the pair starts at time T. Before the swap, the first of them finishes at T + a and the second at T + a + b. After, at T + b and T + a + b. The total changes by b − a, which is negative. **The swap strictly improves the order.**
4. **Conclude.** Any unsorted order can be improved, so no unsorted order is optimal. An optimal order exists (there are finitely many orders), so it's the sorted one.

That's the general shape: take a solution that disagrees with the greedy choice, swap toward the greedy choice, and show it doesn't get worse. When you can't find a swap that works, the counterexample is usually hiding nearby.

> [!note] Adjacent swaps are enough
> You only need to compare neighbors. An array with no adjacent pair out of order is sorted, and an adjacent swap leaves everything outside the pair untouched, which keeps the arithmetic to one line.

## A recipe for greedy problems

When a greedy idea comes to mind, in an interview or at work:

1. **State the rule precisely.** "Sort by end time, take each one that doesn't clash" is a rule; "take the good ones first" isn't.
2. **Attack it with small inputs.** Two or three elements, ties, one huge element, an element that blocks two others. Coin change fell to an input of size 6.
3. **Compare against an exhaustive search** on every small input, if you can write one in a few minutes.
4. **Prove it** with an exchange argument, or at least say the argument out loud. Interviewers ask "why does greedy work here?" more often than they ask for the code.
5. **Cost it.** Most greedy algorithms are a sort plus a pass: O(n log n) time, O(1) or O(n) extra space.

Lesson 2 applies this to intervals, where the right sort key is the whole problem.

## Common mistakes

> [!error] Trusting a rule because it works on the examples
> Greedy coin change gives the right answer for every amount in the examples you'd naturally try: 30, 68, 99 with US coins. The counterexample needs a coin set like 1, 3, 4 and an amount like 6. Look for the counterexample on purpose, and if the problem lets the inputs vary (any coin set), assume someone will pass the bad one.

> [!error] A greedy answer that doesn't add up
> With coins of 5 and 3, `greedyChange(9, coins: [5, 3])` takes the 5, then a 3, and stops with 1 left over: it returns `[5, 3]`, which is 8, not 9. And 9 is reachable as 3 + 3 + 3. Greedy can't back out of the 5. Check that `remaining` is 0 before returning, and return `nil` or throw when it isn't; then use a method that explores alternatives when it matters.

```swift
func greedyChange(_ amount: Int, coins: [Int]) -> [Int] {
    var remaining = amount
    var used: [Int] = []
    for coin in coins.sorted(by: >) {
        while coin <= remaining {
            used.append(coin)
            remaining -= coin
        }
    }
    return used
}

print(greedyChange(9, coins: [5, 3]))
```

```output
[5, 3]
```

> [!error] Sorting by the wrong key
> "Longest first" for the build server looks as plausible as "shortest first" until you run it: 162 against 90. Every greedy rule is a claim about a sort key. Run the alternatives on the same input before you pick.

> [!error] Forgetting to sort
> The greedy step assumes an order. `for coin in coins` instead of `coins.sorted(by: >)` gives `[1, 1, 1, …]` for coins passed as `[1, 5, 10, 25]`: correct total, worst possible count.

## Exercises

````exercise
id: m20-l01-e1
type: comprehension
prompt: Which statement about greedy algorithms is true?
choices:
  - text: "A greedy algorithm is correct when some optimal answer starts with the greedy choice and the rest of the problem is a smaller instance of the same problem."
    correct: true
    why: "That's the greedy-choice property plus optimal substructure. With both, you can make the greedy choice and recurse on what's left."
  - text: "If a greedy rule gives the right answer on every example in the problem statement, it's correct."
    correct: false
    why: "Greedy coin change with 1, 3 and 4 is right for 1 through 5 and wrong for 6. Examples rarely include the counterexample."
  - text: "A greedy algorithm tries every choice and keeps the best one."
    correct: false
    why: "That's exhaustive search or dynamic programming. Greedy makes one choice per step and never revisits it."
  - text: "Greedy algorithms are always O(n)."
    correct: false
    why: "Most of them sort first, which is O(n log n). The pass after the sort is usually O(n)."
solution: |
  **The first.** Correctness comes from the two properties, not from examples. When both hold, an exchange argument usually shows the greedy-choice part: swap a choice in any optimal answer for the greedy one and show it's no worse.
````

````exercise
id: m20-l01-e2
type: prediction
prompt: Predict the exact output. The coins are 1, 5, 6 and 9.
code: |
  func greedyChange(_ amount: Int, coins: [Int]) -> [Int] {
      var remaining = amount
      var used: [Int] = []
      for coin in coins.sorted(by: >) {
          while coin <= remaining {
              used.append(coin)
              remaining -= coin
          }
      }
      return used
  }

  print(greedyChange(11, coins: [1, 5, 6, 9]), greedyChange(12, coins: [1, 5, 6, 9]))
output: |
  [9, 1, 1] [9, 1, 1, 1]
hints:
  - "Sorted descending, the coins are 9, 6, 5, 1. The 9 fits in both amounts."
solution: |
  ```output
  [9, 1, 1] [9, 1, 1, 1]
  ```

  For 11: take 9, leaving 2. Neither 6 nor 5 fits, so two 1s. For 12: take 9, leaving 3, so three 1s. Both are worse than the best answers, 5 + 6 (two coins) and 6 + 6 (two coins). This coin set isn't canonical: taking the 9 is the wrong first choice in both cases.
````

````exercise
id: m20-l01-e3
type: fill-in
prompt: Complete the build-server scheduler. It returns the minimum total waiting time.
code: |
  func minimumTotalWait(_ durations: [Int]) -> Int {
      var clock = 0
      var total = 0
      for duration in durations.[[1]]() {
          clock [[2]] duration
          total += [[3]]
      }
      return total
  }
blanks:
  - id: "1"
    answers: ["sorted"]
  - id: "2"
    answers: ["+="]
  - id: "3"
    answers: ["clock"]
solution: |
  - `sorted`: shortest job first, ascending order.
  - `+=`: the clock advances by each job's duration.
  - `clock`: each developer waits until their job finishes, which is the clock right after it runs.

  ```swift
  func minimumTotalWait(_ durations: [Int]) -> Int {
      var clock = 0
      var total = 0
      for duration in durations.sorted() {
          clock += duration
          total += clock
      }
      return total
  }

  print(minimumTotalWait([8, 3, 12, 1, 5, 7]))
  print(minimumTotalWait([]))
  ```

  ```output
  90
  0
  ```

  Sorting is O(n log n) and the pass is O(n). The exchange argument in the lesson is why sorting ascending is optimal.
````

````exercise
id: m20-l01-e4
type: find-errors
prompt: |
  This function is meant to return the fewest coins that add up to `amount` for **any** coin set passed in any order. Which statements are true?
code: |
  func fewestCoins(_ amount: Int, coins: [Int]) -> [Int] {
      var remaining = amount
      var used: [Int] = []
      for coin in coins {
          while coin <= remaining {
              used.append(coin)
              remaining -= coin
          }
      }
      return used
  }
choices:
  - text: "It doesn't sort the coins, so with coins passed smallest first it hands out only 1s."
    correct: true
    why: "With [1, 5, 10, 25], the 1 coin is tried first and takes the whole amount."
  - text: "Even after sorting descending, it isn't optimal for every coin set."
    correct: true
    why: "With 1, 3 and 4 it makes 6 as 4 + 1 + 1 instead of 3 + 3."
  - text: "It can return coins that don't add up to the amount."
    correct: true
    why: "With coins 5 and 3, sorted, it returns [5, 3] for 9. Without a 1 coin, the leftover can be impossible to pay, and the function never checks remaining."
  - text: "The while should be an if: each coin value can only be used once."
    correct: false
    why: "In coin change each value can be used as many times as needed. The while is right."
rubric:
  - I spotted the missing sort.
  - I explained that greedy isn't optimal for arbitrary coin sets, with a counterexample.
  - I noticed the unchecked remainder.
  - I rejected the while/if distractor.
solution: |
  Three real problems. The missing sort is a bug in the greedy itself. The other two are limits of greedy: it can't back out of a bad first coin, so it can lose on count (1, 3, 4) or fail to finish (5, 3 for 9). Sorting and checking `remaining == 0` makes it honest; making it optimal for any coin set needs the dynamic programming of lesson 4.

  ```swift
  func greedyChange(_ amount: Int, coins: [Int]) -> [Int]? {
      var remaining = amount
      var used: [Int] = []
      for coin in coins.sorted(by: >) {
          while coin <= remaining {
              used.append(coin)
              remaining -= coin
          }
      }
      return remaining == 0 ? used : nil
  }

  print(greedyChange(30, coins: [1, 5, 10, 25]) ?? [])
  print(greedyChange(9, coins: [5, 3]) == nil)
  ```

  ```output
  [25, 5]
  true
  ```

  Returning `nil` for 9 is honest but still wrong, since 3 + 3 + 3 works. Greedy only knows it failed; it can't find the other way.
````

````exercise
id: m20-l01-e5
type: solve
prompt: |
  Delivery drones each carry **at most two packages**, with a total weight of at most `limit`. Every package weighs at most `limit`. Write `func dronesNeeded(_ weights: [Int], limit: Int) -> Int` that returns the fewest drones that can carry all the packages. Aim for O(n log n).

  Then print:

  ```output
  3
  4
  1
  0
  ```

  for `[3, 2, 2, 1]` with limit 3, `[3, 5, 3, 4]` with limit 5, `[1, 2]` with limit 3, and `[]` with limit 10.
starter: |
  func dronesNeeded(_ weights: [Int], limit: Int) -> Int {
      // Sort, then pair the heaviest package with the lightest when they fit together
      return 0
  }
hints:
  - "The heaviest package has to go somewhere. Which package is most likely to fit with it?"
  - "Sort, then keep two indexes: light at the start, heavy at the end. Every drone takes the heavy one; it also takes the light one if both fit."
rubric:
  - The function sorts and uses two indexes moving toward each other.
  - Every step sends one drone with the heaviest remaining package, plus the lightest if they fit together.
  - The loop condition handles the last single package (light == heavy).
  - The four lines match.
solution: |
  ```swift
  func dronesNeeded(_ weights: [Int], limit: Int) -> Int {
      let sorted = weights.sorted()
      var light = 0
      var heavy = sorted.count - 1
      var drones = 0
      while light <= heavy {
          if sorted[light] + sorted[heavy] <= limit {
              light += 1
          }
          heavy -= 1
          drones += 1
      }
      return drones
  }

  print(dronesNeeded([3, 2, 2, 1], limit: 3))
  print(dronesNeeded([3, 5, 3, 4], limit: 5))
  print(dronesNeeded([1, 2], limit: 3))
  print(dronesNeeded([], limit: 10))
  ```

  ```output
  3
  4
  1
  0
  ```

  **The greedy choice:** the heaviest remaining package, H, flies now, with the lightest, L, if they fit. **Exchange argument,** when H + L fits: take any optimal plan in which H flies with some other package x, and L flies with y (or alone). Swap x and L. H + L ≤ H + x, so H's drone is fine. x + y ≤ x + H, because H is the heaviest, so x's new drone is fine too. Same number of drones. If H flies alone in the optimal plan, move L in with it: the count stays the same or drops. Either way, some optimal plan makes the greedy choice.

  When L doesn't fit with H, nothing does, so H flies alone in every plan. When `light == heavy`, one package is left and gets its own drone. With `[]`, `heavy` starts at −1 and the loop never runs. Sorting is O(n log n); the pass is O(n).
````

````exercise
id: m20-l01-e6
type: explain
prompt: |
  A colleague wrote this for a point-of-sale app and says: "Greedy coin change is fine, every country's coins work with it." Explain, in a few sentences, how you'd check that claim for a given coin set, and what you'd use instead when the coin set comes from user input or configuration.
code: |
  func greedyChange(_ amount: Int, coins: [Int]) -> [Int] {
      var remaining = amount
      var used: [Int] = []
      for coin in coins.sorted(by: >) {
          while coin <= remaining {
              used.append(coin)
              remaining -= coin
          }
      }
      return used
  }
rubric:
  - I said that greedy is optimal only for some coin sets (canonical ones), with 1, 3, 4 and the amount 6 as a counterexample.
  - I described checking a specific coin set by comparing greedy against an exhaustive search (or a DP) over a range of amounts.
  - I said that when the coin set isn't fixed and known, you use an algorithm that's correct for any set, such as dynamic programming.
  - I mentioned that a greedy run can also fail to reach the amount at all when there's no 1 coin.
solution: |
  Greedy coin change is optimal for **canonical** coin systems, and US coins are one, but nothing about coins in general guarantees it: with 1, 3 and 4, greedy pays 6 as 4 + 1 + 1 when 3 + 3 is enough. For a specific, fixed coin set, you can collect evidence the way the lesson did: compare greedy against an exhaustive search (or the DP from lesson 4) on every amount up to some bound, and look at any mismatch. If the coin set comes from configuration or user input, don't rely on greedy at all; use the DP, which is correct for every coin set and costs O(amount × number of coins). And check that the amount was actually reached: without a 1 coin, greedy can get stuck with a remainder, as with 5 and 3 for 9.
````

## Summary

- A **greedy algorithm** makes the locally best choice at each step and never undoes it. Usually a sort plus one pass: O(n log n).
- It's correct only with the **greedy-choice property** (some optimal answer starts with the greedy choice) and **optimal substructure** (the rest is a smaller instance of the same problem).
- Greedy coin change is optimal for US coins (no mismatch on any amount from 1 to 99) and wrong for 1, 3 and 4: 24 of 99 amounts, starting with 6 = 4 + 1 + 1 instead of 3 + 3.
- Check a greedy rule by attacking it with small inputs and comparing it against an exhaustive search on every small input. Keep the brute force as a test oracle.
- Prove it with an **exchange argument**: swap a choice in any optimal answer toward the greedy choice and show it's no worse. Shortest job first: an adjacent pair with a > b improves by a − b when swapped.
