---
id: reorder-list
title: Reorder List
difficulty: medium
order: 35
patterns: [Fast and slow pointers, In-place reversal, Merging lists]
prerequisites: [m17-l03, m17-l04]
summary: Relink a list so it alternates between the front and the back. Three linked-list techniques in a row, each one a single pass.
solutionFile: ReorderList.swift
testFile: ReorderListTests.swift
starter: |
  final class ReorderListNode {
      let value: Int
      var next: ReorderListNode?

      init(_ value: Int, next: ReorderListNode? = nil) {
          self.value = value
          self.next = next
      }
  }

  func reorderList(_ head: ReorderListNode?) {
      // Your solution
  }
time: O(n)
space: O(1)
edgeCases:
  - An empty list, one node and two nodes, which stay as they are
  - Three nodes, the smallest case that changes
  - Odd and even lengths
  - The last node's next must end up nil, or the list loops
askInterviewer:
  - Must I relink the existing nodes, or may I just rearrange the values?
  - Is O(n) extra space acceptable?
  - How long can the list be? (A recursive solution could overflow the stack.)
hints:
  - The new order takes one node from the front, then one from the back, then from the front again. What would make "the next node from the back" easy to reach?
  - If the second half were reversed, you'd have two lists to take turns from. How do you find where the second half starts?
  - Find the middle (lesson m17-l04), cut and reverse the second half (lesson m17-l03), then weave the two halves together.
followUps:
  - How would you undo the reordering?
  - What if the pattern were two from the front, then one from the back?
  - Why might an interviewer forbid just swapping the values instead of the nodes?
rubric:
  - I broke the problem into find the middle, reverse the second half, and interleave.
  - I cut the list after the first half so the result ends with nil.
  - I saved both next pointers before relinking during the interleave.
  - I gave O(n) time and O(1) space, and mentioned the array-of-nodes version as the simpler O(n) space option.
codeStatus: tested
---

A photo app's "Memories" slideshow wants to alternate between old and new: the oldest photo, then the newest, then the second oldest, then the second newest, and so on. The photos are a singly linked list from oldest to newest. Write `reorderList(_:)` that relinks the nodes, in place, from `L0 → L1 → … → Ln` to `L0 → Ln → L1 → Ln-1 → L2 → …`. Change links, not values.

In the examples, `makeList` is a test helper that builds a list from an array.

```swift
let photos = makeList([1, 2, 3, 4, 5, 6])
reorderList(photos)        // photos is now 1 → 6 → 2 → 5 → 3 → 4

let odd = makeList([10, 20, 30, 40, 50])
reorderList(odd)           // odd is now 10 → 50 → 20 → 40 → 30
```

**Constraints:** `0 ≤ n ≤ 5 · 10^4`.

<!-- reveal -->

## First approach

The new order pulls from two places: the front, moving forward, and the back, moving backward. A singly linked list only moves forward. So split it in the middle, reverse the second half, and now both "ends" move forward: take turns pulling one node from each. Each step is a technique from module 17, and each is one pass.

## Naive solution

Put every node in an array, where both ends are reachable by index, then relink from the outside in:

```swift
func reorderList(_ head: ReorderListNode?) {
    var nodes: [ReorderListNode] = []
    var current = head
    while let node = current {
        nodes.append(node)
        current = node.next
    }
    var low = 0
    var high = nodes.count - 1
    while low < high {
        nodes[low].next = nodes[high]
        low += 1
        if low == high { break }
        nodes[high].next = nodes[low]
        high -= 1
    }
    if !nodes.isEmpty {
        nodes[low].next = nil
    }
}
```

When the indexes meet, `nodes[low]` is the last node in the new order, so its `next` is cleared.

## Problems with the naive solution

It's O(n) time and much easier to get right, which is worth saying in an interview. But it uses **O(n) extra space** for the array of references, and the problem's point is to manipulate links without it. It also retains every node an extra time while the array exists, a small ARC cost.

## Optimized solution

1. **Find the end of the first half** with fast and slow pointers, stopping at the first middle for even lengths. The first half then has the same number of nodes as the second, or one more. (Stopping at the second middle also works, because the extra front node simply stays at the end.)
2. **Cut and reverse** the second half: remember `slow.next`, set `slow.next = nil` so the first half ends there, and reverse the rest in place.
3. **Interleave**: walk both halves together. For each pair, link the front node to the back node and the back node to the front node's old successor. When the back half runs out, the front half's remaining node (for odd lengths, the middle) already ends with `nil`.

## Line by line

- `guard let head else { return }`: nothing to reorder.
- `while let step = fast.next, let secondStep = step.next, let nextSlow = slow.next`: move slow one step and fast two while fast can take two. `slow` stops at the middle (odd) or first middle (even).
- `var current = slow.next` then `slow.next = nil`: save the start of the second half, then cut. Without the cut, the first half would still lead into the second, and the result would loop.
- The `while let node = current` loop is the in-place reversal: save `next`, point the node at `back`, advance. Afterward `back` is the head of the reversed second half.
- `while let frontNode = front, let backNode = back`: one front node and one back node per iteration.
- `let frontNext = frontNode.next` and `let backNext = backNode.next`: save both successors before changing anything.
- `frontNode.next = backNode` and `backNode.next = frontNext`: splice the back node in after the front node.
- `front = frontNext` and `back = backNext`: move to the next pair.

Finding the middle, reversing and interleaving each touch every node at most once: **O(n) time, O(1) extra space**.

## Common mistakes

- Forgetting `slow.next = nil`. The first half keeps pointing into what's now the reversed second half, and the list becomes a cycle.
- Weaving in the wrong order, back node first. The result starts `Ln → L0 → …`, and the function also has to return a new head, which this signature doesn't allow.
- Overwriting `frontNode.next` before saving it, which loses the rest of the front half.
- Swapping values between nodes instead of relinking. It may give the right printout, but it's not what was asked, and other references to those nodes would see their values change.

## Variation

**Odd-even list**: relink a list so all nodes at odd positions come first, followed by all nodes at even positions, keeping their relative order. Two running tails, one per group, and one pass; at the end, link the odd tail to the even head.
