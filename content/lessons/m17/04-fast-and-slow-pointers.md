---
id: m17-l04
title: Fast and slow pointers
description: You walk a linked list with two references moving at different speeds to find its middle in one pass, detect a cycle with O(1) memory, and find where the cycle starts, and you work through the short proof of why the pointers meet and why the second phase lands on the cycle's first node.
module: m17
order: 4
level: intermediate
minutes: 55
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m17-l03]
objectives:
  - Find the middle node of a linked list in one pass, and choose between the first and second middle.
  - Detect a cycle with Floyd's algorithm in O(n) time and O(1) space, comparing nodes by identity.
  - Find the node where a cycle starts, and prove why the two-phase method works.
  - Explain why a cyclic list of class nodes is a reference cycle under ARC.
  - Apply fast and slow pointers to any sequence produced by repeatedly applying a function.
terms:
  - term: Fast and slow pointers
    definition: Two references that walk the same structure at different speeds, usually one step and two steps at a time. Also called the tortoise and the hare.
  - term: Cycle
    definition: A linked list whose last reachable node points back to an earlier node, so following next never reaches nil.
  - term: "Floyd's cycle detection"
    definition: Detecting a cycle by moving one pointer one step and another two steps at a time. They meet if and only if there's a cycle.
  - term: Cycle start (entry)
    definition: The first node of a list that's inside the cycle, the one reached from both the node before it in the straight part and the last node of the loop.
mastery:
  - Write the middle-node loop with the right stopping condition for odd and even lengths.
  - Write Floyd's cycle detection with === and explain why == on values is wrong.
  - Find the cycle start with a second phase and explain the a = kc − b argument.
  - Compare the fast/slow approach with a Set of visited nodes in time and space.
  - Detect a repeating state in a sequence like "sum of squared digits" without storing the sequence.
resources: [swift-book-structures-classes, swift-book-arc, swift-book-basic-operators, swift-set]
cards:
  - id: m17-l04-c1
    front: How do you find the middle of a linked list in one pass?
    back: "Move slow one step and fast two steps while fast and fast.next exist. When fast reaches the end, slow is at the middle (the second middle for even lengths)."
  - id: m17-l04-c2
    front: Why do fast and slow pointers meet if the list has a cycle?
    back: "Once both are in the cycle, each step the fast one gains exactly one node on the slow one. The gap shrinks by one per step, so it reaches zero within one lap; it can't jump over."
  - id: m17-l04-c3
    front: After fast and slow meet in a cycle, how do you find where the cycle starts?
    back: "Put one pointer back at the head and move both one step at a time. They meet at the cycle start, because the distance from the head to the start equals the distance from the meeting point to the start, plus whole laps."
  - id: m17-l04-c4
    front: Why must cycle detection compare nodes with === and not their values with ==?
    back: Different nodes can hold equal values. Only identity tells you that you're back at the same node.
  - id: m17-l04-c5
    front: What does a cycle in a list of class nodes mean for memory?
    back: "It's a strong reference cycle (Module 13). Every node is kept alive by the one before it, so none is freed when you drop the head. Break the cycle (set one next to nil) first."
---

## The idea in one sentence

Two pointers moving through the same list at different speeds tell you something about its **shape**, where the middle is or whether it loops, with no extra memory and no need to know the length.

## Finding the middle

A podcast app wants to show a preview from the middle of a chapter list. With an Array, it's `chapters[chapters.count / 2]`. With a linked list you don't know the count, and walking once to count and again to stop halfway takes two passes.

Fast and slow pointers do it in one: **slow** moves one node per step, **fast** moves two. When fast reaches the end, slow has gone half as far.

```swift
final class Node {
    let value: Int
    var next: Node?
    init(_ value: Int, next: Node? = nil) {
        self.value = value
        self.next = next
    }
}

func makeList(_ values: [Int]) -> Node? {
    var head: Node? = nil
    for value in values.reversed() {
        head = Node(value, next: head)
    }
    return head
}

func middle(_ head: Node?) -> Node? {
    var slow = head
    var fast = head
    while let next = fast?.next {
        slow = slow?.next
        fast = next.next
    }
    return slow
}

print(middle(makeList([1, 2, 3, 4, 5]))?.value ?? -1)
print(middle(makeList([1, 2, 3, 4, 5, 6]))?.value ?? -1)
print(middle(makeList([7]))?.value ?? -1)
print(middle(makeList([]))?.value ?? -1)
```

```output
3
4
7
-1
```

1. Both pointers start at the head.
2. `while let next = fast?.next` continues only if fast can take **two** steps: `fast` itself must exist and so must the node after it. If either is `nil`, `fast?.next` is `nil` and the loop ends.
3. Inside, slow moves once and fast moves twice (`next.next` is the second step, possibly `nil`).
4. For 5 nodes, fast stops on node 5 (no `next`) after two steps, and slow is on node 3. For 6 nodes, fast steps off the end after three steps, and slow is on node 4: the **second** of the two middles.

After k steps, slow is k nodes from the head and fast is 2k. The loop stops when fast can't go further, about n / 2 steps, so it's **O(n) time and O(1) space**, one pass.

If you need the **first** middle of an even-length list (3 for six nodes), stop one step earlier: loop while `fast?.next?.next` exists. That's the version to use when you split a list in half for merge sort in Module 18, so the left half isn't longer than the right.

## Detecting a cycle

Suppose a bug links the last node of a list back to an earlier one. Now there's no `nil` at the end, and the traversal from lesson 3, `while let node = current`, never stops. Before walking a list you didn't build, you might want to check.

**The simple way**: remember every node you've visited, and stop if you see one again. A `Set` of `ObjectIdentifier` (a hashable wrapper for an instance's identity) does that in O(n) time but **O(n) space**.

**Floyd's algorithm**: run fast and slow from the head. If the list ends, fast finds the `nil`: no cycle. If there's a cycle, fast never finds an end; it laps around and eventually lands on the same node as slow.

```swift
final class Node {
    let value: Int
    var next: Node?
    init(_ value: Int) {
        self.value = value
    }
}

func makeList(_ values: [Int], cycleTo position: Int? = nil) -> Node? {
    let nodes = values.map { Node($0) }
    for index in nodes.indices.dropLast() {
        nodes[index].next = nodes[index + 1]
    }
    if let position, let last = nodes.last {
        last.next = nodes[position]
    }
    return nodes.first
}

func hasCycle(_ head: Node?) -> Bool {
    var slow = head
    var fast = head
    while let next = fast?.next {
        slow = slow?.next
        fast = next.next
        if slow === fast {
            return true
        }
    }
    return false
}

print(hasCycle(makeList([0, 1, 2, 3, 4, 5], cycleTo: 2)))
print(hasCycle(makeList([0, 1, 2, 3, 4, 5])))
print(hasCycle(makeList([0], cycleTo: 0)))
print(hasCycle(makeList([])))
```

```output
true
false
true
false
```

1. `makeList(_:cycleTo:)` is a test helper: it builds the nodes and, if `position` is given, links the last node back to the node at that index. `if let position` (Swift 5.7 shorthand) unwraps the parameter under the same name.
2. The loop is the same as `middle`, plus a check after each step.
3. `slow === fast` compares **identity**: are these the same node? `===` accepts optionals, and two `nil`s can't happen here, because the loop only runs while fast has a next node.
4. A one-node list pointing to itself is a cycle: after one step, slow and fast are both that node.

**Why they must meet.** Once both pointers are inside the cycle, look at the distance from slow forward to fast, counted along the cycle. Each step, slow moves 1 and fast moves 2, so the distance changes by exactly 1. It can't skip over 0: it goes ..., 3, 2, 1, 0. So they meet, and they meet before slow completes a lap of the cycle. Before entering the cycle, slow takes at most n steps. Total: **O(n) time, O(1) space**.

## Finding where the cycle starts

Knowing there's a loop is often not enough: you want the node where it begins, to report or fix the bad link. The method has two phases:

1. Run Floyd's algorithm until slow and fast meet.
2. Put one pointer back at the head. Move it and the other (still at the meeting point) **one step at a time**. Where they meet is the start of the cycle.

```swift
final class Node {
    let value: Int
    var next: Node?
    init(_ value: Int) {
        self.value = value
    }
}

func makeList(_ values: [Int], cycleTo position: Int? = nil) -> Node? {
    let nodes = values.map { Node($0) }
    for index in nodes.indices.dropLast() {
        nodes[index].next = nodes[index + 1]
    }
    if let position, let last = nodes.last {
        last.next = nodes[position]
    }
    return nodes.first
}

func cycleStart(_ head: Node?) -> Node? {
    var slow = head
    var fast = head
    while let next = fast?.next {
        slow = slow?.next
        fast = next.next
        if slow === fast {
            var fromHead = head
            while fromHead !== slow {
                fromHead = fromHead?.next
                slow = slow?.next
            }
            return fromHead
        }
    }
    return nil
}

print(cycleStart(makeList([0, 1, 2, 3, 4, 5], cycleTo: 2))?.value ?? -1)
print(cycleStart(makeList([0, 1, 2, 3, 4, 5], cycleTo: 0))?.value ?? -1)
print(cycleStart(makeList([0, 1, 2, 3, 4, 5], cycleTo: 5))?.value ?? -1)
print(cycleStart(makeList([0, 1, 2]))?.value ?? -1)
```

```output
2
0
5
-1
```

Here's the first list, with 5 linking back to 2:

```text
0 -> 1 -> 2 -> 3 -> 4 -> 5
          ^              |
          +--------------+
```

Phase 1 trace (slow one step, fast two):

| Step | slow | fast |
| --- | --- | --- |
| 0 | 0 | 0 |
| 1 | 1 | 2 |
| 2 | 2 | 4 |
| 3 | 3 | 2 |
| 4 | 4 | 4 |

They meet at node 4. Phase 2: one pointer from the head (0) and one from 4, one step each: 0 and 4, then 1 and 5, then 2 and 2. They meet at node 2, the start.

**Why phase 2 works.** Name three distances:

- **a**: steps from the head to the cycle start (here 2).
- **c**: the cycle's length (here 4: nodes 2, 3, 4, 5).
- **b**: steps from the cycle start to the meeting point, going forward (here 2: from 2 to 4).

When they meet, slow has walked a + b steps. Fast has walked twice as many, 2(a + b), and it's at the same node, so the extra a + b steps it took were whole laps of the cycle:

```text
2(a + b) = (a + b) + k·c    for some whole number k ≥ 1
   a + b = k·c
       a = k·c − b
```

The last line says: walking **a** steps from the meeting point is the same as going back b steps and then k full laps, which lands on the **cycle start**. And walking a steps from the head also lands on the cycle start, by definition of a. So two pointers, one from the head and one from the meeting point, moving one step at a time, arrive at the start together, after exactly a steps. Here a = 2 and c = 4, b = 2, k = 1: 2 = 4 − 2.

Phase 2 is at most a more steps, so the whole thing is still **O(n) time, O(1) space**.

## Cycles and ARC

Module 13 called it a strong reference cycle when objects keep each other alive. A cyclic linked list of class nodes is exactly that: every node is held by the node before it, including the cycle start, which is held by the last node. Dropping the head frees the straight part before the cycle, but never the loop.

```swift
final class Node {
    let name: String
    var next: Node?
    init(_ name: String) {
        self.name = name
    }
    deinit {
        print("freed", name)
    }
}

func makeRing(breakIt: Bool) {
    let first = Node("A")
    let second = Node("B")
    first.next = second
    second.next = first
    if breakIt {
        second.next = nil
    }
}

makeRing(breakIt: false)
print("after the ring")
makeRing(breakIt: true)
print("after the broken ring")
```

```output
after the ring
freed A
freed B
after the broken ring
```

The first call's nodes are never freed: when the function returns, A is still held by B and B by A. In the second, setting `second.next = nil` breaks the loop, so both are freed when the local constants go away. The test lists built with `makeList(_:cycleTo:)` in this lesson leak the same way. In a short program that ends right away it doesn't matter; in an app, a cyclic list is a leak you'd find with the memory graph, as in Module 13. Using `weak` for `next` isn't a fix, since then nothing would hold the list together.

## Beyond linked lists

Floyd's algorithm works on anything where each state has exactly one "next" state: a function applied repeatedly. If the states are finite, the sequence must eventually repeat, which is a cycle, and fast and slow pointers find it without storing the states.

An example: start with a number and repeatedly replace it with the sum of the squares of its digits. From 19: 1² + 9² = 82, then 68, 100, 1, 1, 1, … From 4: 16, 37, 58, 89, 145, 42, 20, 4, and it loops. The exercises use this.

## Common mistakes

> [!error] Checking only fast, not fast.next
> `fast = fast?.next?.next` without a loop condition on `fast?.next` lets fast become `nil` and the loop keep going, or forces you to unwrap. Loop while `fast?.next` exists, and the two-step move is always safe.

> [!error] Comparing values instead of nodes
> `slow?.value == fast?.value` says two nodes **hold equal values**, which happens in plenty of lists without cycles: `1 -> 1 -> 1`. Compare identity with `===`.

> [!error] Checking for a meeting before moving
> Both pointers start at the head, so `slow === fast` is true before the first step. Move first, then compare.

> [!error] Starting phase 2 from the wrong place
> One pointer goes back to the **head**; the other stays at the **meeting point**. Both then move one step at a time. Moving the second one two steps, or resetting both, doesn't land on the start.

> [!error] Forgetting that a cyclic list leaks
> If you build a cycle (in a test or by accident), the nodes in it are never freed. Break the cycle before dropping the list.

## Exercises

````exercise
id: m17-l04-e1
type: comprehension
prompt: "In Floyd's cycle detection, the slow pointer moves 1 step and the fast pointer moves 2. Why is it guaranteed that, if there's a cycle, fast doesn't jump over slow forever?"
choices:
  - text: "Inside the cycle, the distance from slow forward to fast shrinks by exactly one per step, so it must hit zero."
    correct: true
    why: Fast gains one node per step. A distance that changes by 1 at a time can't skip 0.
  - text: Because the cycle's length is always even.
    correct: false
    why: The cycle can have any length, including 1 or an odd number. The argument doesn't depend on it.
  - text: Because fast stops when it reaches nil.
    correct: false
    why: In a cyclic list there's no nil to reach. That's the case where the meeting matters.
  - text: It isn't guaranteed; fast can skip over slow, so the algorithm sometimes needs a third pointer.
    correct: false
    why: With speeds 1 and 2 they always meet within one lap of slow inside the cycle.
solution: |
  **The gap shrinks by one per step.** Once both are in the cycle, measure how many steps fast is behind slow along the cycle. Each step slow adds 1 and fast adds 2, so that gap drops by exactly 1. It goes from some value below the cycle length down to 0 without skipping, and at 0 they're on the same node. That's also why speeds 1 and 2 are the standard choice; with speeds 1 and 3 the gap would shrink by 2 and could jump from 1 to −1, past zero.
````

````exercise
id: m17-l04-e2
type: prediction
prompt: "Predict the exact output. The list is 10 -> 20 -> 30 -> 40 -> 50, with 50 linking back to 30."
code: |
  final class Node {
      let value: Int
      var next: Node?
      init(_ value: Int) {
          self.value = value
      }
  }

  let nodes = [10, 20, 30, 40, 50].map { Node($0) }
  for index in 0..<4 {
      nodes[index].next = nodes[index + 1]
  }
  nodes[4].next = nodes[2]

  var slow: Node? = nodes[0]
  var fast: Node? = nodes[0]
  repeat {
      slow = slow?.next
      fast = fast?.next?.next
      print(slow?.value ?? 0, fast?.value ?? 0)
  } while slow !== fast
  var fromHead: Node? = nodes[0]
  while fromHead !== slow {
      fromHead = fromHead?.next
      slow = slow?.next
  }
  print("start", fromHead?.value ?? 0)
output: |
  20 30
  30 50
  40 40
  start 30
hints:
  - "Fast's path: 10, 30, 50, 40 (50 links back to 30, then 40)."
  - "Phase 2: one pointer from 10, the other from the meeting point, one step each."
solution: |
  ```output
  20 30
  30 50
  40 40
  start 30
  ```

  Phase 1: slow goes 20, 30, 40; fast goes 30, 50, then two steps from 50 is 30 → 40. They meet at 40 after three steps. Phase 2: from 10 and from 40, one step at a time: (10, 40) → (20, 50) → (30, 30). They meet at 30, the cycle start. Check with the formula: a = 2 (10 → 20 → 30), the cycle is 30, 40, 50, so c = 3, and the meeting point is b = 1 step past the start. a + b = 3 = 1 · c. This program leaks the cycle's nodes when it ends, which doesn't matter here.
````

````exercise
id: m17-l04-e3
type: fill-in
prompt: "Complete this function so it returns the **first** middle node for even lengths (3 for six nodes) and the true middle for odd lengths. It should print `3 3 1`."
code: |
  final class Node {
      let value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func firstMiddle(_ head: Node?) -> Node? {
      var slow = head
      var fast = head
      while let afterNext = fast?.[[1]]?.[[2]] {
          slow = slow?.next
          fast = [[3]]
      }
      return slow
  }

  func makeList(_ values: [Int]) -> Node? {
      var head: Node? = nil
      for value in values.reversed() {
          head = Node(value, next: head)
      }
      return head
  }

  let even = firstMiddle(makeList([1, 2, 3, 4, 5, 6]))?.value ?? -1
  let odd = firstMiddle(makeList([1, 2, 3, 4, 5]))?.value ?? -1
  let one = firstMiddle(makeList([1]))?.value ?? -1
  print(even, odd, one)
blanks:
  - id: "1"
    answers: ["next"]
  - id: "2"
    answers: ["next"]
  - id: "3"
    answers: ["afterNext"]
solution: |
  ```swift
  final class Node {
      let value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func firstMiddle(_ head: Node?) -> Node? {
      var slow = head
      var fast = head
      while let afterNext = fast?.next?.next {
          slow = slow?.next
          fast = afterNext
      }
      return slow
  }

  func makeList(_ values: [Int]) -> Node? {
      var head: Node? = nil
      for value in values.reversed() {
          head = Node(value, next: head)
      }
      return head
  }

  let even = firstMiddle(makeList([1, 2, 3, 4, 5, 6]))?.value ?? -1
  let odd = firstMiddle(makeList([1, 2, 3, 4, 5]))?.value ?? -1
  let one = firstMiddle(makeList([1]))?.value ?? -1
  print(even, odd, one)
  ```

  ```output
  3 3 1
  ```

  The loop now continues only if fast can land **two** nodes ahead, and it moves fast straight there. For six nodes, fast visits 1, 3, 5 and stops (5 has only one node after it), so slow takes two steps and stops on 3. The lesson's version loops while `fast?.next` exists and lets fast step off the end, which takes one more step and lands on 4. For odd lengths both versions agree.
````

````exercise
id: m17-l04-e4
type: find-errors
prompt: This cycle detector gives wrong answers. Which statements are true?
code: |
  final class Node {
      let value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func hasCycle(_ head: Node?) -> Bool {
      var slow = head
      var fast = head
      while fast != nil {
          slow = slow?.next
          fast = fast?.next?.next
          if slow?.value == fast?.value {
              return true
          }
      }
      return false
  }

  print(hasCycle(Node(1, next: Node(1, next: Node(1)))))
  print(hasCycle(Node(5)))
choices:
  - text: "It returns true for 1 -> 1 -> 1, which has no cycle."
    correct: true
    why: After one step, slow is on the second node and fast on the third. Different nodes, equal values.
  - text: "It returns true for a single node with no cycle."
    correct: true
    why: "After one step both are nil, and nil == nil is true for optionals."
  - text: It can loop forever on a list that has a cycle.
    correct: false
    why: In a cycle the pointers do end up on the same node, which also has the same value, so it returns true.
  - text: It crashes on an empty list.
    correct: false
    why: "fast is nil, so the loop never runs and it returns false."
rubric:
  - I identified comparing values instead of identity.
  - "I identified the nil == nil case when fast and slow both run off the end."
  - I rewrote the loop to require fast?.next and compare with ===.
  - I kept O(n) time and O(1) space.
solution: |
  Both wrong answers come from the comparison. `==` on the optional values says two nodes hold equal numbers, or that both pointers are `nil`, neither of which means "same node". The fix compares identity, and only steps while fast can move twice:

  ```swift
  final class Node {
      let value: Int
      var next: Node?
      init(_ value: Int, next: Node? = nil) {
          self.value = value
          self.next = next
      }
  }

  func hasCycle(_ head: Node?) -> Bool {
      var slow = head
      var fast = head
      while let next = fast?.next {
          slow = slow?.next
          fast = next.next
          if slow === fast {
              return true
          }
      }
      return false
  }

  print(hasCycle(Node(1, next: Node(1, next: Node(1)))))
  print(hasCycle(Node(5)))
  let looped = Node(1, next: Node(2))
  looped.next?.next = looped
  print(hasCycle(looped))
  ```

  ```output
  false
  false
  true
  ```

  With the loop condition on `fast?.next`, fast is never `nil` at the top of a pass, and after a pass at most fast is `nil` while slow isn't, so `===` can't match two `nil`s. O(n) time, O(1) space.
````

````exercise
id: m17-l04-e5
type: solve
prompt: |
  A habit app awards a badge for "happy" numbers: repeatedly replace the number with the sum of the squares of its digits; the number is happy if this reaches 1. Otherwise the sequence loops forever without reaching 1. Write `func isHappy(_ n: Int) -> Bool` using fast and slow pointers, **without** storing the sequence. Assume `n` is positive.

  Expected output for the starter's call:

  ```output
  [1, 7, 10, 13, 19, 23, 28, 31]
  ```
starter: |
  func digitSquareSum(_ n: Int) -> Int {
      var number = n
      var sum = 0
      while number > 0 {
          let digit = number % 10
          sum += digit * digit
          number /= 10
      }
      return sum
  }

  func isHappy(_ n: Int) -> Bool {
      // slow applies digitSquareSum once per step, fast twice
      return false
  }

  print((1...31).filter(isHappy))
hints:
  - "The sequence has only one \"next\" for each number, like a linked list's next. Reaching 1 is like reaching the end: 1 maps to 1."
  - Loop until slow == fast. Then the sequence is in a cycle, and the number is happy only if that cycle is 1 itself.
rubric:
  - Uses slow (one application) and fast (two applications) with no Set or array of seen values.
  - Stops when they meet, and returns whether the meeting value is 1.
  - The output matches.
  - Explains why == is fine here (numbers, not nodes) and why the loop terminates.
solution: |
  ```swift
  func digitSquareSum(_ n: Int) -> Int {
      var number = n
      var sum = 0
      while number > 0 {
          let digit = number % 10
          sum += digit * digit
          number /= 10
      }
      return sum
  }

  func isHappy(_ n: Int) -> Bool {
      var slow = n
      var fast = digitSquareSum(n)
      while slow != fast {
          slow = digitSquareSum(slow)
          fast = digitSquareSum(digitSquareSum(fast))
      }
      return slow == 1
  }

  print((1...31).filter(isHappy))
  ```

  ```output
  [1, 7, 10, 13, 19, 23, 28, 31]
  ```

  `digitSquareSum` plays the role of `next`. Every sequence ends up in a cycle: either the one-element cycle 1 → 1 (happy) or a longer loop (for 4: 4, 16, 37, 58, 89, 145, 42, 20, 4). Floyd's argument guarantees slow and fast meet inside whichever cycle it is, so the loop ends, and checking whether they met at 1 answers the question. Starting fast one step ahead avoids the "equal before moving" mistake. Here `==` is right, because a state **is** a number: two equal numbers have the same next value, unlike two nodes that merely hold equal values. Space is O(1). The time depends on how long the sequence takes to enter its cycle, which is short: any number with d digits maps to at most 81·d, so values quickly fall below a few hundred.
````

````exercise
id: m17-l04-e6
type: explain
prompt: |
  In your own words, explain why the second phase of this function returns the first node of the cycle. Use the distances a (head to cycle start), b (cycle start to meeting point) and c (cycle length).
code: |
  func cycleStart(_ head: Node?) -> Node? {
      var slow = head
      var fast = head
      while let next = fast?.next {
          slow = slow?.next
          fast = next.next
          if slow === fast {
              var fromHead = head
              while fromHead !== slow {
                  fromHead = fromHead?.next
                  slow = slow?.next
              }
              return fromHead
          }
      }
      return nil
  }
rubric:
  - "States that at the meeting, slow has walked a + b and fast 2(a + b)."
  - "Derives that a + b is a whole number of laps, a + b = k·c, so a = k·c − b."
  - Concludes that a steps from the meeting point land on the cycle start, as do a steps from the head.
  - Notes that both pointers move one step at a time in phase 2, and the total stays O(n).
solution: |
  When they meet, slow has walked **a + b** steps: a to reach the cycle, then b inside it. Fast moves twice as fast, so it has walked **2(a + b)**, and it's on the same node. The extra a + b steps fast took can only have been spent going around the cycle, so a + b is a whole number of laps: **a + b = k·c** for some k ≥ 1, which means **a = k·c − b**.

  Now think about a pointer at the meeting point, which is b steps past the cycle start. Walking a more steps means walking k·c − b: b steps short of k full laps, measured from b past the start. That lands exactly on the cycle start. A pointer at the head also reaches the cycle start after a steps, by the definition of a. So if both move one step at a time, they're on the same node for the first time at the cycle start, after a steps, and the inner loop returns it. (Before that, the one from the head is still on the straight part, outside the cycle, so they can't meet early.) Phase 1 is O(n) and phase 2 is a ≤ n more steps, so the whole function is O(n) time with O(1) space.
````

## Summary

- **Fast and slow pointers** walk the same list at speeds 2 and 1. With no length known, they find positions and shapes in one pass and O(1) space.
- **Middle**: loop while `fast?.next` exists; slow ends on the middle (the second middle for even lengths). Loop while `fast?.next?.next` exists for the first middle.
- **Cycle detection** (Floyd): move, then compare with `===`. In a cycle the gap shrinks by one per step, so they meet; otherwise fast reaches `nil`. O(n) time, O(1) space, versus O(n) space for a `Set` of visited nodes.
- **Cycle start**: after they meet, move one pointer from the head and one from the meeting point, one step each. Since a + b = k·c, they meet at the start.
- A cyclic list of class nodes is a **strong reference cycle**: break it, or it leaks.
- The same technique finds loops in any "apply a function repeatedly" sequence, without storing it.
