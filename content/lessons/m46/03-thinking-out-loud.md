---
id: m46-l03
title: Thinking out loud and communicating trade-offs
description: You learn what to say while solving a problem and what to leave out, how to state complexity at each step instead of only at the end, when to offer the brute force first, and how to compare several correct solutions in a few sentences. A fictional interview exchange on a new problem, with four tested solutions, shows the whole thing.
module: m46
order: 3
level: intermediate
minutes: 50
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m46-l02]
objectives:
  - Narrate a solution with short statements of intent, observation and cost instead of reading code aloud.
  - State time and space complexity for every approach as soon as you propose it.
  - Decide whether to code the brute force or only describe it.
  - Compare several correct solutions in a short trade-off statement and say which you'd pick and when you'd switch.
terms:
  - term: Thinking out loud
    definition: Saying your reasoning as you work, so the interviewer can follow it, check it and steer you. It's about decisions and observations, not about every keystroke.
  - term: Trade-off
    definition: What one solution gains and gives up compared with another, such as speed for memory or simplicity for generality.
  - term: XOR
    definition: "The bitwise exclusive or operator, ^ in Swift. a ^ a is 0, a ^ 0 is a, and the order doesn't matter, so XOR-ing a set of numbers twice cancels them out."
  - term: Signpost
    definition: A short sentence that says where you are in the method, like "I have a working idea; let me check the edge cases before I code it."
mastery:
  - Narrate a solution in statements of intent, observation and cost, with no long silences and no code dictation.
  - Give time and space for each approach the moment you propose it, naming n.
  - Explain when the brute force is worth coding and when one sentence is enough.
  - Write a trade-off statement comparing two solutions that ends with a choice and a condition for switching.
resources: [swift-set, swift-array, swift-array-sort, swift-book-basic-operators]
cards:
  - id: m46-l03-c1
    front: What three kinds of sentences carry most of thinking out loud?
    back: "Intent (what I'm about to do and why), observation (what I noticed about the problem or the trace), and cost (what this approach takes in time and space)."
  - id: m46-l03-c2
    front: When should you code the brute force instead of only describing it?
    back: "When n is small enough that it's acceptable, when you don't see an optimization after a couple of minutes, or when the interviewer asks for it. Otherwise describe it in one sentence with its complexity and move on."
  - id: m46-l03-c3
    front: "Tickets 1 to n with one missing: four solutions and their costs?"
    back: "Sort and scan, O(n log n) time and O(n) space for the copy. A Set, O(n) average time and O(n) space. Sum formula, O(n) time and O(1) space, with an overflow caveat. XOR, O(n) time and O(1) space, no overflow."
  - id: m46-l03-c4
    front: What's the shape of a good trade-off statement?
    back: "Option A gains … and costs …; option B gains … and costs …. I'd pick A here because of [a constraint]. If [the constraint] changed, I'd switch to B."
  - id: m46-l03-c5
    front: What should you say when you need silence to think?
    back: "Say it: \"Let me think about this for a minute.\" A stated pause is fine; an unexplained one leaves the interviewer guessing whether you're stuck."
---

## The idea in one sentence

Think out loud in short statements of **intent, observation and cost**, so the interviewer can follow your decisions, not your keystrokes.

## Why talk at all

An interviewer can only evaluate what they can see and hear. A correct solution typed in silence tells them you got there, not how; a wrong turn explained out loud shows judgment, and it lets them steer you before you lose ten minutes. Talking also helps you: saying "this works because…" is often the moment you notice it doesn't.

That doesn't mean narrating everything. Three kinds of sentences carry almost all the value:

| Kind | Example |
| --- | --- |
| **Intent**: what you're about to do and why | "I'll write the brute force first so we have a baseline." |
| **Observation**: what you noticed | "The numbers are exactly 1 to n with one gap, so I know what the total should be." |
| **Cost**: time and space | "That's one pass, O(n) time, and only a running total, so O(1) space." |

Everything else is optional. Two things are worth avoiding:

- **Dictating code.** "For i in zero dot dot less than count, open brace…" Nobody needs that. Say what the loop is for: "Now I walk the array once and subtract each ticket."
- **Unexplained silence.** You're allowed to stop and think. Say so: "Give me a minute to check the loop condition." A stated pause reads as care; a long unexplained one reads as stuck.

When you move from one phase to the next, a **signpost** helps both of you: "I have an idea I think works. Before coding it, let me check it on the edge cases."

## State complexity as you go

Give time and space the moment you propose an approach, not just at the end. It's what makes the next sentence ("so let's do better") make sense, and it keeps you honest: if you can't say the cost of an idea, you don't understand it well enough to code it yet.

Always say what n is. "O(n), where n is the number of tickets."

## Brute force first?

Almost always **say** the brute force; only sometimes **code** it.

- **Code it** when the input is small enough that it's acceptable, when you don't see a better idea after a couple of minutes (a working answer beats an unfinished clever one), or when the interviewer asks.
- **Describe it in one sentence** when you already see a clean better solution and time matters: "Checking every pair is O(n²); I think a set gets this to O(n)."

Either way, the brute force is the reference you test the fast version against (lesson 1).

## A fictional exchange

The following conversation is invented to show the technique. It isn't a transcript of any real interview.

> **Interviewer:** An event sold tickets numbered 1 to n. You get the numbers of the tickets that were scanned at the door, in any order. Exactly one ticket wasn't scanned. Return its number.
>
> **Candidate:** So I get n − 1 distinct numbers from the range 1 to n, unordered, and I return the one that's missing. Can the array be empty?
>
> **Interviewer:** Yes. That means n is 1 and nobody was scanned.
>
> **Candidate:** Then the answer is 1. And how large can n be?
>
> **Interviewer:** Up to a million.
>
> **Candidate:** OK. The first thing that comes to mind is sorting: after sorting, ticket k should be at index k − 1, and the first place where that's not true is the gap. If there's no gap, the missing one is n. That's O(n log n) for the sort, and O(n) space for the sorted copy. It works, but I don't need the order, only the gap.
>
> A set would avoid sorting: put every ticket in a set and check 1 to n. O(n) average time, but still O(n) space.
>
> Actually, I know exactly which numbers should be there, so I know what they should add up to: n(n + 1) / 2. The missing ticket is that total minus the sum of the scanned ones. One pass, O(n) time, O(1) space.
>
> **Interviewer:** Any concerns with that?
>
> **Candidate:** Overflow. The total is about n²/2. With n up to a million that's about 5 × 10¹¹, nowhere near `Int.max` on a 64-bit platform, so it's fine here. If n could be in the billions it would get close. There's an XOR version that can't overflow, but it's harder to read. I'll code the sum version and mention XOR at the end.
>
> **Interviewer:** Go ahead.

Notice what the candidate did: restated the problem with the details made explicit, asked about the two things that change the code (empty input and size), named each approach with its cost in one breath, and chose based on a constraint. The candidate never read code aloud.


## The four solutions

All four, checked against the same cases:

```swift
func missingTicketBySorting(_ tickets: [Int]) -> Int {
    let sorted = tickets.sorted()
    for (index, ticket) in sorted.enumerated() where ticket != index + 1 {
        return index + 1
    }
    return sorted.count + 1
}

func missingTicketBySet(_ tickets: [Int]) -> Int {
    let n = tickets.count + 1
    let scanned = Set(tickets)
    for candidate in 1..<n where !scanned.contains(candidate) {
        return candidate
    }
    return n
}

func missingTicketBySum(_ tickets: [Int]) -> Int {
    let n = tickets.count + 1
    let expected = n * (n + 1) / 2
    return expected - tickets.reduce(0, +)
}

func missingTicketByXOR(_ tickets: [Int]) -> Int {
    var result = 0
    for number in 1...(tickets.count + 1) {
        result ^= number
    }
    for ticket in tickets {
        result ^= ticket
    }
    return result
}

let cases: [[Int]] = [[3, 1, 5, 2], [2], [1], [], [1, 2, 3]]
for tickets in cases {
    print(tickets,
          missingTicketBySorting(tickets),
          missingTicketBySet(tickets),
          missingTicketBySum(tickets),
          missingTicketByXOR(tickets))
}
```

```output
[3, 1, 5, 2] 4 4 4 4
[2] 1 1 1 1
[1] 2 2 2 2
[] 1 1 1 1
[1, 2, 3] 4 4 4 4
```

The lines worth explaining:

- **Sorting.** After sorting, ticket k belongs at index k − 1. The first index where it doesn't is the gap. If the loop finishes, every ticket from 1 to `count` is present, so the missing one is `count + 1`.
- **Set.** The loop checks `1..<n`, a half-open range. With an empty array, n is 1 and `1..<1` is simply empty, so the function returns 1. Writing `1...tickets.count` instead would build `1...0` for the empty case, and a closed range with its lower bound above its upper bound stops the program with `Range requires lowerBound <= upperBound`. That's the kind of detail a hand trace on `[]` catches (lesson 4).
- **Sum.** `reduce(0, +)` adds up the array. The expected total minus the actual total is the missing number.
- **XOR.** `^` is bitwise exclusive or (the Swift book covers it under Advanced Operators). Two facts make it work: `a ^ a` is 0 and `a ^ 0` is `a`, and the order of the operations doesn't matter. XOR-ing every number from 1 to n and then every scanned ticket cancels each present number with itself, leaving only the missing one. The values never grow beyond the bits already in n, so it can't overflow.

## Communicating the trade-offs

Four correct answers, four different costs. The table is what you'd want in your head:

| Approach | Time | Extra space | Notes |
| --- | --- | --- | --- |
| Sort and scan | O(n log n) | O(n) for the sorted copy | Easiest to explain; does more work than needed |
| Set | O(n) on average | O(n) | Works even if the numbers aren't 1 to n, just "find what's absent from a known range" |
| Sum formula | O(n) | O(1) | Shortest code; relies on exactly one missing value; overflow when n is in the billions |
| XOR | O(n) | O(1) | No overflow; harder to read and to explain |

Out loud, you don't recite the table. You give a **trade-off statement**: two options, what each gains and costs, a choice tied to a constraint, and the condition under which you'd switch.

> "The set version and the sum version are both O(n). The set needs O(n) memory; the sum needs O(1) but only works because exactly one ticket is missing. With n up to a million, the sum can't overflow, so I'd use it. If two tickets could be missing, I'd go back to the set, because one total can't tell two missing numbers apart."

That last sentence is the one that shows judgment. It answers a follow-up before it's asked.

## Narration: rambling versus clear

Here's the same moment narrated two ways. Rambling:

> "OK so, hmm, I guess I could, like, sort it? Or maybe a dictionary. Let me just start typing and see. So `let sorted equals tickets dot sorted`. Wait, no. Actually maybe the sum thing. I'm not sure if that's right. Sorry, give me a second."

Clear:

> "Two options: sort and scan, O(n log n), or compute the expected sum, O(n) and O(1) space. The sum works because exactly one number is missing. I'll do the sum. Let me take a few seconds to check overflow before I write it."

The clear version is shorter and contains more information: two approaches, their costs, a reason, a choice and a stated pause. It doesn't apologize.

## Common mistakes

> [!error] Narrating syntax instead of decisions
> Reading code aloud fills the silence without telling the interviewer anything. Say what a block is for ("this loop finds the first gap"), not how it's spelled.

> [!error] Saving the complexity for the end
> If the interviewer hears "O(n²)" only after you've coded it, they couldn't redirect you earlier. State the cost when you propose the idea.

> [!error] A trade-off with no decision
> "The set uses more memory but the sum might overflow" stops halfway. Finish it: which one, why, and when you'd switch.

> [!error] Going quiet when stuck
> Silence hides the most useful information you have: where you're stuck. "I can do it in O(n log n) but I don't see how to avoid the sort" invites a hint. Lesson 6 covers getting unstuck.

> [!error] Agreeing with every hint
> If the interviewer suggests something and you don't see why it works, say so and ask. Nodding and then coding something you don't understand is worse than a short question.

## Exercises

````exercise
id: m46-l03-e1
type: comprehension
prompt: You've just thought of a hash-set approach for a problem where n can be 10⁵. Which sentence is the best thing to say next?
choices:
  - text: "\"A set of what I've seen gives O(n) average time and O(n) extra space, instead of O(n²) for checking every pair. Let me check it on the empty case before I code it.\""
    correct: true
    why: Intent, cost with n implied by context, a comparison with the baseline and a signpost for what comes next.
  - text: "\"I'm going to use a set. Let var seen equal Set open paren close paren.\""
    correct: false
    why: It dictates code and says nothing about why the set helps or what it costs.
  - text: "\"I think a set might work, but I'm not sure, sorry.\""
    correct: false
    why: No cost, no reason, and an apology. If you're unsure, say what you're unsure about.
  - text: Nothing yet; explain everything once the code is done.
    correct: false
    why: The interviewer can't redirect you if they only hear the plan after it's built.
solution: |
  The first one. It names the approach, its time and space, compares it with the brute force, and says what you'll do next. The interviewer now knows enough to say "sounds good" or "what about memory?" before you write anything.
````

````exercise
id: m46-l03-e2
type: prediction
prompt: This traces the XOR solution for tickets `[4, 1, 2]` with n = 4. Predict the output.
code: |
  var result = 0
  for number in 1...4 {
      result ^= number
      print("after \(number): \(result)")
  }
  for ticket in [4, 1, 2] {
      result ^= ticket
      print("after ticket \(ticket): \(result)")
  }
  print(result)
output: |
  after 1: 1
  after 2: 3
  after 3: 0
  after 4: 4
  after ticket 4: 0
  after ticket 1: 1
  after ticket 2: 3
  3
hints:
  - "In binary: 1 is 001, 2 is 010, 3 is 011, 4 is 100. XOR sets each bit where exactly one of the two numbers has it."
  - After XOR-ing 1 through 4, the tickets cancel the numbers that are present.
solution: |
  ```output
  after 1: 1
  after 2: 3
  after 3: 0
  after 4: 4
  after ticket 4: 0
  after ticket 1: 1
  after ticket 2: 3
  3
  ```

  In binary: 0 ^ 001 = 001 (1); 001 ^ 010 = 011 (3); 011 ^ 011 = 000 (0); 000 ^ 100 = 100 (4). Then the tickets: 100 ^ 100 = 0; 0 ^ 001 = 1; 001 ^ 010 = 011 (3). Every present number appears twice and cancels; 3 appears once, so it's what remains. The intermediate values jump around, which is why XOR is harder to explain than the sum, even though it can't overflow.
````

````exercise
id: m46-l03-e3
type: solve
prompt: |
  New problem: an event printed tickets 1 to n, but one number was printed **twice** by mistake, so the scanned array has n + 1 numbers and every number from 1 to n appears at least once. Return the duplicated number.

  Write two versions: `duplicatedTicketBySet` (stop at the first number already seen) and `duplicatedTicketBySum` (O(1) extra space). Then write the trade-off statement you'd say out loud. Expected output for the starter's calls:

  ```output
  3 3
  1 1
  4 4
  ```
starter: |
  func duplicatedTicketBySet(_ tickets: [Int]) -> Int {
      return 0
  }

  func duplicatedTicketBySum(_ tickets: [Int]) -> Int {
      return 0
  }

  for tickets in [[3, 1, 3, 2], [1, 1], [2, 4, 1, 3, 4]] {
      print(duplicatedTicketBySet(tickets), duplicatedTicketBySum(tickets))
  }
hints:
  - "For the set: insert(_:) returns a tuple whose inserted is false when the value was already there."
  - For the sum, n is tickets.count − 1. The actual total is the expected total plus the duplicate.
rubric:
  - The set version returns as soon as it sees a repeat.
  - The sum version computes n from the count and subtracts the expected total.
  - "Both versions give the right output, including [1, 1]."
  - The trade-off statement gives time and space for both, picks one, and names a condition for switching.
solution: |
  ```swift
  func duplicatedTicketBySet(_ tickets: [Int]) -> Int {
      var seen = Set<Int>()
      for ticket in tickets where !seen.insert(ticket).inserted {
          return ticket
      }
      preconditionFailure("Every ticket was unique")
  }

  func duplicatedTicketBySum(_ tickets: [Int]) -> Int {
      let n = tickets.count - 1
      return tickets.reduce(0, +) - n * (n + 1) / 2
  }

  for tickets in [[3, 1, 3, 2], [1, 1], [2, 4, 1, 3, 4]] {
      print(duplicatedTicketBySet(tickets), duplicatedTicketBySum(tickets))
  }
  ```

  ```output
  3 3
  1 1
  4 4
  ```

  `preconditionFailure` documents that the loop must return for valid input; reaching it means the input broke the agreed rules.

  A trade-off statement:

  > "The set version is O(n) average time and O(n) space, and it can stop early at the first repeat. The sum version is O(n) time and O(1) space, but it only works because the rules guarantee exactly one duplicate and every other number exactly once. With those rules, I'd pick the sum. If the input could have several duplicates or missing numbers, I'd switch to the set, because one total can't separate them."
````

````exercise
id: m46-l03-e4
type: explain
prompt: Rewrite this narration so it's clear and short. Keep every piece of real information, cut the rest, and add anything important that's missing.
code: |
  // "Um, so, I'm thinking maybe two loops? Like for every element,
  //  go through all the other elements and check, um, if they add up.
  //  That's probably slow but whatever. Or wait, maybe I should sort it.
  //  Sorry, I always get confused with these. OK, let me just write
  //  the two loops. For i in zero dot dot less than n..."
rubric:
  - Names the brute force (every pair) with its cost, O(n²) time and O(1) space.
  - Mentions sorting as an alternative with its cost (O(n log n)) and what it enables (two pointers).
  - Makes a choice and gives a reason tied to a constraint (or asks for the constraint).
  - No apology, no dictated code.
solution: |
  One possible rewrite:

  > "The direct approach is to check every pair: O(n²) time, O(1) space. If I sort first, I can use two pointers from both ends, which is O(n log n) overall. How large can the input get? If it's small I'll write the pair check; if it's large, the sorted version."

  The original had two real ideas (all pairs, sorting) and no costs. The rewrite keeps both ideas, attaches a cost to each, asks the question that decides between them, and drops the apology and the dictation. It's shorter and tells the interviewer more.
````

````exercise
id: m46-l03-e5
type: find-errors
prompt: A candidate summarizes the complexity of their missing-ticket solutions. Which claims are wrong?
code: |
  // 1. "Sort and scan is O(n log n) time and O(1) extra space."
  // 2. "The set version is O(n) on average, because insert and contains
  //     are O(1) on average."
  // 3. "The sum version is O(1) time, because it's just a formula."
  // 4. "XOR is O(n) time and O(1) space, and it can't overflow."
choices:
  - text: "Claim 1: sorted() returns a new array, so it's O(n) extra space."
    correct: true
    why: tickets.sorted() copies the array. Sorting in place would need a var copy or an inout parameter.
  - text: "Claim 3: the formula is O(1), but summing the scanned tickets is O(n)."
    correct: true
    why: reduce(0, +) visits every element. The whole function is O(n) time and O(1) space.
  - text: "Claim 2 is wrong: Set operations are O(log n)."
    correct: false
    why: Swift's Set is hash-based. Insertion and lookup are O(1) on average, so building it and checking 1 to n is O(n) on average.
  - text: "Claim 4 is wrong: XOR of large numbers can overflow."
    correct: false
    why: XOR never produces a bit that wasn't set in one of its operands, so the result stays within the bit width of the largest number.
rubric:
  - I found the space mistake in claim 1 and the time mistake in claim 3.
  - I explained why claims 2 and 4 are correct.
solution: |
  Claims 1 and 3 are wrong. `sorted()` allocates a new array, so sorting costs O(n) extra space; and "just a formula" ignores the O(n) pass that adds up the scanned tickets. A useful habit: for every line, ask "does this touch every element?" and "does this allocate something proportional to n?"

  Claims 2 and 4 are right. A Swift `Set` is a hash table, O(1) on average per operation. XOR only combines bits that already exist, so it can't overflow, which is its advantage over the sum.
````

## Summary

- Talk in three kinds of sentences: **intent** (what and why), **observation** (what you noticed) and **cost** (time and space). Don't dictate code; announce pauses instead of going silent.
- State the complexity of each approach when you propose it, naming n.
- Always say the brute force; code it when n is small, when you're stuck, or when asked.
- Missing ticket: sort and scan O(n log n), set O(n) with O(n) space, sum O(n) with O(1) space (overflow only for n in the billions), XOR O(n) with O(1) space and no overflow.
- A trade-off statement has two options, their gains and costs, a choice tied to a constraint, and the condition for switching.
- A half-open range (`1..<n`) is empty when the bounds are equal; a closed range (`1...0`) with crossed bounds stops the program.
