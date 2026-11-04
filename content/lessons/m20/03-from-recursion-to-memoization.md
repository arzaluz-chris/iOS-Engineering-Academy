---
id: m20-l03
title: From recursion to memoization
description: You take a plain recursion that repeats work, name the two properties that make it a dynamic programming problem, define its state as the smallest set of parameters that decides the answer, and add a memo keyed by that state. You count the calls before and after on a message decoder and a phone-keypad puzzle with a two-part state, and see the mistakes that make a memo wrong or useless.
module: m20
order: 3
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m20-l02]
objectives:
  - Recognize overlapping subproblems in a recursion by finding arguments that repeat.
  - Define the state of a subproblem as the parameters that fully determine its answer.
  - Add a memo dictionary keyed by the state, local to one top-level call, and measure the calls it saves.
  - Estimate the cost of a memoized recursion as number of states times work per state.
terms:
  - term: Dynamic programming
    definition: Solving a problem by combining the answers to smaller subproblems, computing each distinct subproblem once. Top-down (memoization) or bottom-up (tabulation).
  - term: Overlapping subproblems
    definition: A recursion has them when the same subproblem, the same arguments, is reached through different chains of calls. That repetition is what a memo removes.
  - term: State
    definition: The values that identify a subproblem and fully determine its answer, usually the parameters of the recursive function. Two calls with the same state must return the same result.
  - term: Memo
    definition: The dictionary (or array) that maps a state to its computed answer. Checked before computing, written right after.
  - term: Top-down dynamic programming
    definition: Writing the natural recursion from the full problem down to the base cases and adding a memo. Only the states the recursion actually reaches get computed.
mastery:
  - Point at the repeated calls in a recursion's call tree.
  - Name the state of a recursive function and say why each part of it is needed.
  - Add a memo to a recursion so it checks before computing and stores before returning.
  - Explain why a memo keyed by too little gives wrong answers and one keyed by too much gives no hits.
  - Give the time and space of a memoized recursion from its states and transitions.
resources: [swift-dictionary, swift-book-functions, swift-book-structures-classes, swift-array]
cards:
  - id: m20-l03-c1
    front: What two properties make a problem a dynamic programming problem?
    back: Overlapping subproblems (the same subproblem shows up through different paths) and optimal substructure (the answer to a problem is built from answers to its subproblems).
  - id: m20-l03-c2
    front: What is the state of a recursive subproblem?
    back: The smallest set of values that determines its answer. Two calls with the same state must return the same result, so the state is the memo's key.
  - id: m20-l03-c3
    front: Memo key with too little information? Too much?
    back: Too little, and different subproblems share an entry, so answers are wrong. Too much (like the path taken so far), and no two calls share an entry, so the memo never hits.
  - id: m20-l03-c4
    front: Cost of a memoized recursion?
    back: Number of distinct states times the work per state (the transitions), plus O(states) memory for the memo and O(depth) for the call stack.
  - id: m20-l03-c5
    front: Why can't a memo dictionary use the key (Int, Int)?
    back: "Tuples don't conform to Hashable in Swift. Define a small struct with the fields and declare it Hashable: struct State: Hashable { let key: Int; let hopsLeft: Int }."
---

## The idea in one sentence

When a recursion reaches the same subproblem through different paths, **compute each one once and look it up the other times**; the work drops from the number of paths to the number of distinct subproblems.

You've seen it twice: memoized Fibonacci in Module 15 and grid paths at the end of Module 18's first lesson. This lesson turns it from a trick into a method, so you can apply it to a recursion you've never seen.

## A recursion that repeats itself

A puzzle app encodes messages as digits: A is 1, B is 2, up to Z, 26. "226" can be read as 2 2 6 (BBF), 22 6 (VF) or 2 26 (BZ), so it has 3 decodings. How many does a message have?

Standing at position i, there are at most two choices: read one digit (if it isn't 0), or read two (if they form 10 to 26). The answer from i is the sum of the answers after each choice:

```swift
func decodings(_ message: String) -> (ways: Int, calls: Int) {
    let digits = message.compactMap { $0.wholeNumberValue }
    var calls = 0

    func ways(from i: Int) -> Int {
        calls += 1
        if i == digits.count {
            return 1
        }
        if digits[i] == 0 {
            return 0
        }
        var total = ways(from: i + 1)
        if i + 1 < digits.count && digits[i] * 10 + digits[i + 1] <= 26 {
            total += ways(from: i + 2)
        }
        return total
    }

    return (ways(from: 0), calls)
}

print(decodings("226"))
print(decodings("2106"))
print(decodings("1111111111"))
print(decodings("1212121212121212121212121"))
```

```output
(ways: 3, calls: 7)
(ways: 1, calls: 6)
(ways: 89, calls: 232)
(ways: 121393, calls: 317810)
```

- `compactMap { $0.wholeNumberValue }` turns the characters into digits once, so the recursion works on an `[Int]` and an index.
- **Base case:** `i == digits.count` means the whole message was read, which counts as one complete decoding.
- **A dead end:** no letter starts with 0, so a 0 in reading position gives no decodings. That's how "2106" ends up with just one (2 10 6).
- The two-digit read needs a first digit that isn't 0 (already checked) and a value of at most 26.
- `ways` is a nested function, so it can read `digits` and update `calls` without passing them along.

The 25-digit message makes 317,810 calls for 25 positions. Here's why, for "1111":

```text
ways(0)
├── ways(1)
│   ├── ways(2)
│   │   ├── ways(3)
│   │   │   └── ways(4)
│   │   └── ways(4)
│   └── ways(3)
│       └── ways(4)
└── ways(2)
    ├── ways(3)
    │   └── ways(4)
    └── ways(4)
```

`ways(2)` is computed twice and `ways(3)` three times, and each copy redoes its whole subtree. With all 1s and 2s, every position has two choices, and the tree is the Fibonacci tree from Module 15 in disguise.

## The two properties

A problem is a dynamic programming problem when its recursion has:

1. **Overlapping subproblems.** The same subproblem is reached by different chains of calls. Above, `ways(from: 2)` is reached by reading "1" "1" and by reading "11". Merge sort, by contrast, never sorts the same half twice; divide and conquer without overlap gains nothing from a memo.
2. **Optimal substructure.** The answer to the problem is built from the answers to its subproblems. For counting, that means the count from i is the sum of the counts after each choice, and the choices don't interfere with each other. For optimization (fewest coins, longest sequence), it means the best answer contains best answers to its subproblems.

Optimal substructure can fail. The longest path between two points in a graph that never revisits a node doesn't break into longest paths between intermediate points, because the two halves might reuse the same node. That's why no memo fixes it.

## Defining the state

The **state** is what identifies a subproblem. For `ways(from:)`, it's `i`: the number of ways to decode the rest of the message depends only on where you are, not on how you got there. "2 2" and "22" both leave you at position 2 with the same "6" to decode.

The question that finds a state: **after some choices are made, what do I need to know to solve the rest?** Include exactly that:

- **Everything that affects the answer.** If two calls can have the same state and different answers, something's missing.
- **Nothing else.** The choices that led here, the partial answer, a counter of calls: none of that changes the answer for the rest, so none of it goes in the key.
- **Inputs that never change** (the message itself) aren't part of the state. They're fixed for the whole run.

That's why the function had to be written with `i` as its only parameter. A recursion that builds the decoded string as it goes, passing it down, would have to be rewritten first: the partial string makes every call unique.

## Adding the memo

A dictionary from state to answer, checked before computing and filled right after:

```swift
func decodingsMemo(_ message: String) -> (ways: Int, calls: Int, stored: Int) {
    let digits = message.compactMap { $0.wholeNumberValue }
    var calls = 0
    var memo: [Int: Int] = [:]

    func ways(from i: Int) -> Int {
        calls += 1
        if i == digits.count {
            return 1
        }
        if digits[i] == 0 {
            return 0
        }
        if let known = memo[i] {
            return known
        }
        var total = ways(from: i + 1)
        if i + 1 < digits.count && digits[i] * 10 + digits[i + 1] <= 26 {
            total += ways(from: i + 2)
        }
        memo[i] = total
        return total
    }

    return (ways(from: 0), calls, memo.count)
}

print(decodingsMemo("226"))
print(decodingsMemo("1212121212121212121212121"))
print(decodingsMemo(String(repeating: "12", count: 40)))
```

```output
(ways: 3, calls: 6, stored: 3)
(ways: 121393, calls: 50, stored: 25)
(ways: 37889062373143906, calls: 160, stored: 80)
```

Three lines changed: the dictionary, the lookup before the work, and the store after it. The rest is the same recursion.

| Message | Without memo | With memo | Stored states |
| --- | --- | --- | --- |
| "226" | 7 calls | 6 calls | 3 |
| 25 digits | 317,810 calls | 50 calls | 25 |
| 80 digits | (don't try) | 160 calls | 80 |

Each position is computed once and called at most twice (once from one step back, once from two steps back): about 2n calls, so **O(n) time** and **O(n) space** for the memo plus O(n) stack depth. The 80-digit answer is about 3.8 × 10¹⁶; the plain recursion would make more calls than that.

> [!note] Where the memo lives
> `memo` is a local variable of `decodingsMemo`, captured by the nested function. Each top-level call starts with an empty memo, which is what you want: the answers are about one message. Module 15 passed the memo with `inout` instead, which works the same. A global `var memo` doesn't compile in a Swift 6 `main.swift` without more work (top-level variables are isolated to the main actor), and it's the wrong design anyway, as the first common mistake below shows.

## A state with two parts

A phone keypad, with a chess knight on it. The knight moves in an L: two keys one way, one key across. From 1 it can reach 6 or 8; from 5, nothing. How many different numbers of a given length can you dial by starting on any key and making only knight moves?

```text
1 2 3
4 5 6
7 8 9
  0
```

After some moves, what do you need to know to count the rest? **Where the knight is** and **how many moves are left**. Both. The dictionary key has to hold both, and since tuples aren't `Hashable` in Swift, you declare a small struct:

```swift
let knightMoves: [[Int]] = [
    [4, 6], [6, 8], [7, 9], [4, 8], [0, 3, 9],
    [], [0, 1, 7], [2, 6], [1, 3], [2, 4],
]

struct State: Hashable {
    let key: Int
    let hopsLeft: Int
}

func numbersNaive(length: Int) -> (count: Int, calls: Int) {
    var calls = 0
    func count(from key: Int, hopsLeft: Int) -> Int {
        calls += 1
        if hopsLeft == 0 {
            return 1
        }
        var total = 0
        for next in knightMoves[key] {
            total += count(from: next, hopsLeft: hopsLeft - 1)
        }
        return total
    }
    var total = 0
    for key in 0...9 {
        total += count(from: key, hopsLeft: length - 1)
    }
    return (total, calls)
}

func numbersMemo(length: Int) -> (count: Int, calls: Int, stored: Int) {
    var calls = 0
    var memo: [State: Int] = [:]
    func count(from key: Int, hopsLeft: Int) -> Int {
        calls += 1
        if hopsLeft == 0 {
            return 1
        }
        let state = State(key: key, hopsLeft: hopsLeft)
        if let known = memo[state] {
            return known
        }
        var total = 0
        for next in knightMoves[key] {
            total += count(from: next, hopsLeft: hopsLeft - 1)
        }
        memo[state] = total
        return total
    }
    var total = 0
    for key in 0...9 {
        total += count(from: key, hopsLeft: length - 1)
    }
    return (total, calls, memo.count)
}

for length in [1, 2, 3, 10, 15] {
    print(length, numbersNaive(length: length), numbersMemo(length: length))
}
```

```output
1 (count: 10, calls: 10) (count: 10, calls: 10, stored: 0)
2 (count: 20, calls: 30) (count: 20, calls: 30, stored: 10)
3 (count: 46, calls: 76) (count: 46, calls: 50, stored: 19)
10 (count: 14912, calls: 26556) (count: 14912, calls: 190, stored: 82)
15 (count: 944000, calls: 1672188) (count: 944000, calls: 290, stored: 127)
```

- `knightMoves[k]` lists the keys a knight can reach from key k. Index 5 is empty.
- `State` gets `Hashable` (and `Equatable`) synthesized because both of its properties are `Int`. Module 10's `Seat` worked the same way.
- The memo version is the naive one plus the same three lines: build the key, look it up, store the result.
- For length 15, 1,672,188 calls become 290. There are at most 10 keys × 14 move counts = 140 states, and each makes at most 3 calls; that bound, about 420 calls, is the cost: **O(10 × n × 3) = O(n)**.

The naive count grows by roughly 2.6× per extra digit. Memoized, each extra digit adds 20 calls.

## The recipe

To go from a problem to a memoized solution:

1. **Write the recursion** so the answer for a subproblem depends only on the function's parameters. Base cases first.
2. **Name the state:** the parameters that change between calls. Check that two calls with the same state must return the same answer.
3. **Add the memo:** a dictionary from state to answer, created once per top-level call. Look up after the base cases, store just before returning.
4. **Cost it:** number of states × work per state for time; number of states for the memo, plus the recursion depth for the stack.

Step 1 is the hard one. Once the recursion is pure in its parameters, steps 2 and 3 are mechanical.

> [!warning] A memo doesn't make the recursion shallower
> `decodingsMemo` on a 200,000-digit message still recurses 200,000 levels deep on its first path down, and Module 18 showed a debug build crashing at around 100,000 frames. Memoization fixes the time, not the depth. Lesson 4 fills the same answers in a loop, from the smallest subproblem up, which fixes both.

## Common mistakes

> [!error] A memo shared between different inputs
> The memo's entries are answers for one input. Reuse the dictionary for another, and stale answers come back. This version passes the memo with `inout` and the caller reuses it:

```swift
func ways(_ digits: [Int], from i: Int, memo: inout [Int: Int]) -> Int {
    if i == digits.count {
        return 1
    }
    if digits[i] == 0 {
        return 0
    }
    if let known = memo[i] {
        return known
    }
    var total = ways(digits, from: i + 1, memo: &memo)
    if i + 1 < digits.count && digits[i] * 10 + digits[i + 1] <= 26 {
        total += ways(digits, from: i + 2, memo: &memo)
    }
    memo[i] = total
    return total
}

var memo: [Int: Int] = [:]
print(ways([2, 2, 6], from: 0, memo: &memo))
print(ways([9, 9, 9], from: 0, memo: &memo))
```

```output
3
3
```

"999" decodes only one way, but `memo[0]` still holds 3 from "226". Either the state includes the input (it shouldn't, it's huge), or the memo starts empty for each input. Make the memo a local of the top-level function.

> [!error] A state that's missing a part
> Keying the knight memo by `key` alone makes "from 4 with 3 hops left" and "from 4 with 1 hop left" share one entry. Whichever is computed first answers both. Exercise 4 runs it.

> [!error] A state with too much in it
> Put the digits dialed so far into the key, and every call has a different key:

```swift
let knightMoves: [[Int]] = [
    [4, 6], [6, 8], [7, 9], [4, 8], [0, 3, 9],
    [], [0, 1, 7], [2, 6], [1, 3], [2, 4],
]

func numbersKeyedByPath(length: Int) -> (count: Int, calls: Int, hits: Int) {
    var memo: [String: Int] = [:]
    var calls = 0
    var hits = 0

    func count(typed: String, key: Int, hopsLeft: Int) -> Int {
        calls += 1
        if hopsLeft == 0 {
            return 1
        }
        if let known = memo[typed] {
            hits += 1
            return known
        }
        var total = 0
        for next in knightMoves[key] {
            total += count(typed: typed + String(next), key: next, hopsLeft: hopsLeft - 1)
        }
        memo[typed] = total
        return total
    }

    var total = 0
    for key in 0...9 {
        total += count(typed: String(key), key: key, hopsLeft: length - 1)
    }
    return (total, calls, hits)
}

print(numbersKeyedByPath(length: 10))
```

```output
(count: 14912, calls: 26556, hits: 0)
```

The answer is right and the memo is useless: 26,556 calls, exactly the naive count, and zero hits. Each path is a different string, so nothing repeats. The path doesn't affect how many numbers can follow; only the current key and the hops left do.

> [!error] error: type '(Int, Int)' does not conform to protocol 'Hashable'
> Swift 6.3 rejects a tuple as a dictionary key. Declare a struct with the same fields and `Hashable`; the conformance is synthesized when every stored property is `Hashable`.

```swift no-compile type '(Int, Int)' does not conform to protocol 'Hashable'
var memo: [(Int, Int): Int] = [:]
memo[(3, 2)] = 46
print(memo)
```

> [!error] Storing in the memo but never reading it
> A memo that's written after the recursion but checked nowhere (or checked after the recursive calls) saves nothing. The lookup goes **before** any recursive call; the store goes **after** the result is known.

## Exercises

````exercise
id: m20-l03-e1
type: comprehension
prompt: |
  A robot starts at (0, 0) on an empty grid and makes exactly k moves, each one up, down, left or right. You want the number of move sequences that end at (x, y). Which state identifies the subproblem "count the ways to finish from here"?
choices:
  - text: "The current row, the current column and the number of moves left."
    correct: true
    why: "Where you are and how many moves remain decide how many ways you can still end at the target. The target and k are fixed inputs."
  - text: "The current row and column."
    correct: false
    why: "With 2 moves left and with 6 moves left, the counts from the same cell differ. Two different subproblems would share a memo entry."
  - text: "The list of moves made so far."
    correct: false
    why: "That determines the position, but it's different for every path, so the memo would never hit."
  - text: "The number of moves left."
    correct: false
    why: "From different cells with the same moves left, the counts differ."
solution: |
  **Row, column and moves left.** Apply the question "after some choices, what do I need to know to solve the rest?": the position, because the target is fixed, and the moves left, because that bounds what's reachable. The move history determines the position, but it carries far more than that, and different histories that end at the same cell with the same moves left have the same answer. A `struct State: Hashable { let row: Int; let column: Int; let movesLeft: Int }` is the memo key; with coordinates bounded by k in each direction there are O(k³) states.
````

````exercise
id: m20-l03-e2
type: prediction
prompt: Predict the exact output. `count` is the decoder's recursion, with a call counter and an optional memo.
code: |
  func decode(_ digits: [Int], useMemo: Bool) -> (Int, Int) {
      var calls = 0
      var memo: [Int: Int] = [:]
      func ways(from i: Int) -> Int {
          calls += 1
          if i == digits.count {
              return 1
          }
          if digits[i] == 0 {
              return 0
          }
          if useMemo, let known = memo[i] {
              return known
          }
          var total = ways(from: i + 1)
          if i + 1 < digits.count && digits[i] * 10 + digits[i + 1] <= 26 {
              total += ways(from: i + 2)
          }
          memo[i] = total
          return total
      }
      return (ways(from: 0), calls)
  }

  print(decode([1, 1, 1, 1], useMemo: false))
  print(decode([1, 1, 1, 1], useMemo: true))
  print(decode([2, 7, 2, 7], useMemo: true))
output: |
  (5, 12)
  (5, 8)
  (1, 5)
hints:
  - "Count the nodes of the call tree for \"1111\" drawn in the lesson."
  - "With the memo, ways(0) down to ways(4) is the first path. Then count the second calls on the way back up."
  - "In 2727, 27 is too big, so every position has one choice."
solution: |
  ```output
  (5, 12)
  (5, 8)
  (1, 5)
  ```

  - **Without the memo:** the tree in the lesson has 12 nodes. "1111" decodes 5 ways (1 1 1 1, 11 1 1, 1 11 1, 1 1 11, 11 11).
  - **With the memo:** the first path is `ways(0)` → `(1)` → `(2)` → `(3)` → `(4)`: 5 calls. On the way back up, `ways(3)` has no second call (only one digit left), `ways(2)` calls `ways(4)`, a base case (6), `ways(1)` calls `ways(3)`, a memo hit (7), and `ways(0)` calls `ways(2)`, another hit (8). The saving looks small at n = 4; the lesson's 25-digit message goes from 317,810 calls to 50.
  - **"2727":** 27 > 26, so no two-digit reads. One chain of 5 calls and one decoding (B G B G). Without overlap, the memo has nothing to save.
````

````exercise
id: m20-l03-e3
type: fill-in
prompt: Complete the memoized knight-dialer count.
code: |
  func count(from key: Int, hopsLeft: Int) -> Int {
      if hopsLeft == 0 {
          return [[1]]
      }
      let state = State(key: key, hopsLeft: hopsLeft)
      if let known = memo[[[2]]] {
          return known
      }
      var total = 0
      for next in knightMoves[key] {
          total += count(from: next, hopsLeft: [[3]])
      }
      memo[state] = [[4]]
      return total
  }
blanks:
  - id: "1"
    answers: ["1"]
  - id: "2"
    answers: ["state"]
  - id: "3"
    answers: ["hopsLeft - 1", "hopsLeft-1"]
  - id: "4"
    answers: ["total"]
solution: |
  - `1`: with no hops left, the digits typed so far are one complete number.
  - `state`: the lookup uses the same key as the store.
  - `hopsLeft - 1`: each move uses one hop. That's what makes the recursion reach the base case.
  - `total`: store the answer right before returning it.

  ```swift
  let knightMoves: [[Int]] = [
      [4, 6], [6, 8], [7, 9], [4, 8], [0, 3, 9],
      [], [0, 1, 7], [2, 6], [1, 3], [2, 4],
  ]

  struct State: Hashable {
      let key: Int
      let hopsLeft: Int
  }

  func numbers(startingAt start: Int, length: Int) -> Int {
      var memo: [State: Int] = [:]
      func count(from key: Int, hopsLeft: Int) -> Int {
          if hopsLeft == 0 {
              return 1
          }
          let state = State(key: key, hopsLeft: hopsLeft)
          if let known = memo[state] {
              return known
          }
          var total = 0
          for next in knightMoves[key] {
              total += count(from: next, hopsLeft: hopsLeft - 1)
          }
          memo[state] = total
          return total
      }
      return count(from: start, hopsLeft: length - 1)
  }

  print(numbers(startingAt: 1, length: 2), numbers(startingAt: 5, length: 2), numbers(startingAt: 4, length: 3))
  ```

  ```output
  2 0 6
  ```

  From 1, the knight reaches 6 or 8: 2 two-digit numbers. From 5 it can't move. From 4 it reaches 0, 3 or 9, and each of those has 2 moves: 6.
````

````exercise
id: m20-l03-e4
type: find-errors
prompt: |
  This memoized knight dialer returns 10 and 20 for lengths 1 and 2, correctly, and then wrong counts for longer numbers. Which statements are true?
code: |
  func numbers(length: Int) -> Int {
      var memo: [Int: Int] = [:]
      func count(from key: Int, hopsLeft: Int) -> Int {
          if hopsLeft == 0 {
              return 1
          }
          if let known = memo[key] {
              return known
          }
          var total = 0
          for next in knightMoves[key] {
              total += count(from: next, hopsLeft: hopsLeft - 1)
          }
          memo[key] = total
          return total
      }
      var total = 0
      for key in 0...9 {
          total += count(from: key, hopsLeft: length - 1)
      }
      return total
  }
choices:
  - text: "The memo key is missing hopsLeft, so counts for the same key with different hops left overwrite and answer for each other."
    correct: true
    why: "The first time key 6 is stored might be with 1 hop left; later, a call from 6 with 2 hops left gets that answer."
  - text: "The fix is a key that holds both values, like a Hashable struct with key and hopsLeft."
    correct: true
    why: "That's the full state: two calls with the same key and hops left always have the same answer."
  - text: "The memo should be a global variable so it persists across calls to numbers(length:)."
    correct: false
    why: "That makes it worse: answers from one length would leak into the next. A local memo per call is right."
  - text: "The base case should return 0, since no number is dialed."
    correct: false
    why: "With no hops left, the digits typed so far form exactly one number. Returning 0 would make every count 0."
rubric:
  - I identified the incomplete state (key without hopsLeft) as the bug.
  - I proposed a Hashable struct key with both values.
  - I explained why the length 1 and 2 cases happen to work.
solution: |
  The state is (key, hops left), and the memo only uses the key. For length 2 every memo entry is written with 1 hop left and only read with 1 hop left, so the bug hides. From length 3 on, the first answer stored for a key gets returned for every other hop count. The fix, run:

  ```swift
  let knightMoves: [[Int]] = [
      [4, 6], [6, 8], [7, 9], [4, 8], [0, 3, 9],
      [], [0, 1, 7], [2, 6], [1, 3], [2, 4],
  ]

  struct State: Hashable {
      let key: Int
      let hopsLeft: Int
  }

  func numbers(length: Int, fullState: Bool) -> Int {
      var memo: [State: Int] = [:]
      func count(from key: Int, hopsLeft: Int) -> Int {
          if hopsLeft == 0 {
              return 1
          }
          let state = State(key: key, hopsLeft: fullState ? hopsLeft : 0)
          if let known = memo[state] {
              return known
          }
          var total = 0
          for next in knightMoves[key] {
              total += count(from: next, hopsLeft: hopsLeft - 1)
          }
          memo[state] = total
          return total
      }
      var total = 0
      for key in 0...9 {
          total += count(from: key, hopsLeft: length - 1)
      }
      return total
  }

  for length in [2, 3, 4] {
      print(length, numbers(length: length, fullState: false), numbers(length: length, fullState: true))
  }
  ```

  ```output
  2 20 20
  3 32 46
  4 40 104
  ```

  With `fullState: false`, the key ignores the hops, which reproduces the bug: from length 3 on, the memo returns whatever answer was stored first for each key, and the counts come out as 32 and 40 instead of 46 and 104.
````

````exercise
id: m20-l03-e5
type: solve
prompt: |
  A social app turns hashtags into readable text: `#swiftuiapp` becomes "swift ui app". Write `func canSplit(_ text: String, into words: Set<String>) -> Bool` that returns whether `text` can be split into a sequence of words from `words` (each word can be used any number of times). Write it as a recursion over a start index, then add a memo. The last test is there to time out without the memo.

  Print:

  ```output
  true
  true
  false
  false
  ```

  for `"swiftuiapp"` with `["swift", "swiftui", "ui", "app"]`, `"appleapp"` with `["apple", "app"]`, `"applepi"` with `["apple", "pie"]`, and 40 `"a"` characters followed by `"b"` with `["a", "aa", "aaa"]`.
starter: |
  func canSplit(_ text: String, into words: Set<String>) -> Bool {
      let characters = Array(text)
      var memo: [Int: Bool] = [:]

      func canSplit(from start: Int) -> Bool {
          // Base case: start == characters.count
          // Try every end after start; if characters[start..<end] is a word,
          // and the rest can be split, return true.
          return false
      }

      return canSplit(from: 0)
  }
hints:
  - "The state is the start index: whether the rest of the text can be split depends only on where it starts."
  - "String(characters[start..<end]) builds the candidate word; words.contains checks it in O(1) on average."
  - "Store the result for start in memo before returning, both for true and for false."
rubric:
  - The recursion has the right base case (an empty rest can be split).
  - The memo is keyed by the start index, checked before the loop and written before returning.
  - The adversarial input finishes immediately.
  - The four lines match.
solution: |
  ```swift
  func canSplit(_ text: String, into words: Set<String>) -> Bool {
      let characters = Array(text)
      var memo: [Int: Bool] = [:]

      func canSplit(from start: Int) -> Bool {
          if start == characters.count {
              return true
          }
          if let known = memo[start] {
              return known
          }
          var result = false
          for end in (start + 1)...characters.count {
              let candidate = String(characters[start..<end])
              if words.contains(candidate) && canSplit(from: end) {
                  result = true
                  break
              }
          }
          memo[start] = result
          return result
      }

      return canSplit(from: 0)
  }

  print(canSplit("swiftuiapp", into: ["swift", "swiftui", "ui", "app"]))
  print(canSplit("appleapp", into: ["apple", "app"]))
  print(canSplit("applepi", into: ["apple", "pie"]))
  print(canSplit(String(repeating: "a", count: 40) + "b", into: ["a", "aa", "aaa"]))
  ```

  ```output
  true
  true
  false
  false
  ```

  **State:** the start index. Whether `text[start...]` can be split doesn't depend on how the beginning was split. **Overlap:** in the all-`a` input, position 6 is reached by "aaa aaa", "aa aa aa", "a aa aaa" and many more; without the memo, each of those re-explores the whole tail, and since the `b` makes every attempt fail, the search tries every way to split 40 `a`s into pieces of 1 to 3, and there are 23,837,527,729 of those. **Cost with the memo:** n + 1 states, each trying up to n end positions and building a substring of up to n characters, so O(n³) in the worst case for n characters; limiting `end` to `start + longestWordLength` brings it down when words are short. `Array(text)` makes the slicing by integer index possible, as in Module 16.
````

````exercise
id: m20-l03-e6
type: explain
prompt: |
  Explain why memoizing this function changes its time from exponential to O(n), and what it doesn't change. Use the words state, transitions and depth.
code: |
  func ways(from i: Int) -> Int {
      if i == digits.count {
          return 1
      }
      if digits[i] == 0 {
          return 0
      }
      if let known = memo[i] {
          return known
      }
      var total = ways(from: i + 1)
      if i + 1 < digits.count && digits[i] * 10 + digits[i + 1] <= 26 {
          total += ways(from: i + 2)
      }
      memo[i] = total
      return total
  }
rubric:
  - "I said the state is i, with n + 1 possible values, and that each state's body runs at most once."
  - "I said each state has at most two transitions (i + 1 and i + 2), so the total number of calls is O(n)."
  - "I said the plain recursion's calls grow like Fibonacci numbers because the same i is recomputed in every path that reaches it."
  - "I said the recursion depth stays O(n), so the stack still grows with the input, and memory is O(n) for the memo."
solution: |
  The **state** is `i`, and it takes n + 1 values. With the memo, the body below the lookup runs at most once per state: the first call computes and stores, every later call returns the stored value. Each body makes at most two **transitions**, to `i + 1` and `i + 2`, so the total number of calls is at most about 2n: O(n) time.

  Without the memo, the same `i` is recomputed once for every path of one- and two-digit reads that reaches it. For a message of 1s and 2s, that number grows like the Fibonacci numbers, which is exponential: 317,810 calls for 25 digits.

  What doesn't change is the **depth**. The first chain of calls still goes `ways(0)`, `ways(1)`, …, `ways(n)` before anything returns: n + 1 frames. Add the memo's n entries, and the space is O(n). For very long inputs the depth is the limit, which the bottom-up table in lesson 4 removes.
````

## Summary

- Dynamic programming applies when a recursion has **overlapping subproblems** and **optimal substructure**. Divide and conquer without overlap gains nothing from a memo.
- The **state** is what you need to know to solve the rest, and nothing more. Find it with: "after some choices, what do I need to know?" Fixed inputs aren't part of it.
- **Memoize** in three lines: a dictionary keyed by the state, local to the top-level call; a lookup after the base cases; a store before returning. For a multi-part state, use a `Hashable` struct; tuples can't be keys.
- Measured: the decoder went from 317,810 calls to 50 on 25 digits; the knight dialer from 1,672,188 to 290 for length 15.
- Cost: states × work per state, O(states) memory, and the recursion depth is unchanged.
- Missing part of the state gives wrong answers; extra parts (like the path so far) give zero memo hits.
