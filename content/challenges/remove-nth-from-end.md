---
id: remove-nth-from-end
title: Remove Nth Node From the End
difficulty: medium
order: 36
patterns: [Two pointers with a gap, Dummy head]
prerequisites: [m17-l03, m17-l04]
summary: Delete the node n places from the end in a single pass. Two pointers n nodes apart, and a dummy head so deleting the first node isn't special.
solutionFile: RemoveNthFromEnd.swift
testFile: RemoveNthFromEndTests.swift
starter: |
  final class RemoveNthListNode {
      let value: Int
      var next: RemoveNthListNode?

      init(_ value: Int, next: RemoveNthListNode? = nil) {
          self.value = value
          self.next = next
      }
  }

  func removeNthFromEnd(_ head: RemoveNthListNode?, _ n: Int) -> RemoveNthListNode? {
      // Your solution
      return head
  }
time: O(L)
space: O(1)
edgeCases:
  - Removing the head (n equal to the length)
  - Removing the last node (n = 1)
  - A one-node list, which becomes empty
  - n larger than the length, or less than 1
askInterviewer:
  - Is n always between 1 and the length, or should I handle values outside that range?
  - Do you want one pass specifically, or is two passes fine?
  - Should I return the new head?
hints:
  - Removing a node means changing its predecessor's next. Which node do you need to stop on?
  - If one pointer is n nodes ahead of another, where is the trailing pointer when the leading one reaches the last node?
  - The node to remove might be the head, which has no predecessor. Lesson m17-l03 has a trick for that.
followUps:
  - Is the one-pass version actually faster than two passes? (Both do about L steps; one pass reads each node once instead of twice.)
  - How would you return the n-th node from the end without removing it?
  - What if the list were doubly linked with a tail reference?
rubric:
  - I explained the two-pass version and its cost.
  - I kept two pointers n nodes apart and moved them together.
  - I used a dummy head so removing the first node is not a special case.
  - I handled n out of range without crashing.
codeStatus: tested
---

A notification center stores notifications as a singly linked list from oldest to newest. The user swipes away "the n-th most recent" one. Write `removeNthFromEnd(_:_:)` that removes the node `n` positions from the end (`n = 1` is the last node) and returns the head of the resulting list. If `n` is less than 1 or greater than the length, return the list unchanged. Walk the list only once.

In the examples, `makeList` is a test helper that builds a list from an array.

```swift
removeNthFromEnd(makeList([10, 20, 30, 40, 50]), 2)   // 10 → 20 → 30 → 50
removeNthFromEnd(makeList([10, 20, 30]), 3)           // 20 → 30
removeNthFromEnd(makeList([7]), 1)                    // nil
removeNthFromEnd(makeList([1, 2, 3]), 4)              // 1 → 2 → 3
```

**Constraints:** `0 ≤ L ≤ 10^4` for a list of length L; `n` is any `Int`.

<!-- reveal -->

## First approach

Counting from the end is counting from the start if you know the length: the n-th from the end is at index L − n. To remove it, you stop on the node before it. The one-pass version avoids measuring L: if a pointer starts n nodes ahead and both move together, the trailing one is n nodes behind the leader the whole way, so when the leader is on the last node, the trailing one is right before the target. A dummy node in front of the head gives even the head a predecessor.

## Naive solution

Two passes: count, then walk to the predecessor:

```swift
func removeNthFromEnd(_ head: RemoveNthListNode?, _ n: Int) -> RemoveNthListNode? {
    var length = 0
    var current = head
    while let node = current {
        length += 1
        current = node.next
    }
    guard n >= 1, n <= length else { return head }
    if n == length {
        return head?.next
    }
    var previous = head
    for _ in 0..<(length - n - 1) {
        previous = previous?.next
    }
    previous?.next = previous?.next?.next
    return head
}
```

## Problems with the naive solution

It's O(L) time and O(1) space, so it isn't slow. Its weaknesses are that it walks the list **twice**, which the problem rules out (think of a list being read from a slow source), and that removing the head needs its own branch, a classic place for off-by-one errors. The optimized version fixes both.

## Optimized solution

Put a dummy node before the head. Move `lead` n steps forward from the dummy; if it runs out first, n is larger than the length, so return the list as is. Then start `trail` at the dummy and move both pointers one step at a time until `lead` is on the last node. `trail` is now n + 1 nodes before the end, the predecessor of the node to remove. Unlink it and return `dummy.next`, which is the new head whether or not the old head was removed.

## Line by line

- `guard n >= 1 else { return head }`: zero or a negative n removes nothing.
- `let dummy = RemoveNthListNode(0, next: head)`: its value is never read.
- `for _ in 0..<n` with `guard let next = lead.next else { return head }`: move the leader n nodes past the dummy. Running out means n > L.
- `var trail = dummy`: the trailing pointer is now exactly n nodes behind `lead`.
- `while let next = lead.next, let trailNext = trail.next`: advance both until `lead` has no successor, meaning it's the last node. `trail.next` always exists here, since `trail` is behind `lead`; binding it avoids a force unwrap.
- `trail.next = trail.next?.next`: skip the target. ARC frees it.
- `return dummy.next`: the head, or the old second node if the head was removed, or `nil` if the list is now empty.

`lead` moves L steps in total and `trail` fewer: **O(L) time, O(1) space**, in one pass.

## Common mistakes

- Stopping `lead` at `nil` instead of at the last node. Then `trail` ends on the target itself, which you can't remove from a singly linked list without its predecessor.
- Starting both pointers at `head` instead of a dummy. Removing the head then needs a separate check, and the obvious version crashes or removes the wrong node.
- Moving `lead` n − 1 or n + 1 steps. Trace a three-node list with n = 1 and n = 3 to check the gap.
- Force-unwrapping `lead.next` in the first loop, which crashes when n is larger than the length.

## Variation

**Rotate a list right by k**: move the last k nodes to the front. Find the length and the tail, reduce k with `k % length`, use the same gap idea to find the new tail (the node L − k − 1 from the start), cut after it, and link the old tail to the old head.
