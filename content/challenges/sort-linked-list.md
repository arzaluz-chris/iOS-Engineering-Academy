---
id: sort-linked-list
title: Sort a Linked List
difficulty: medium
order: 61
patterns: [Merge sort, Fast and slow pointers, Linked list]
prerequisites: [m17-l03, m17-l04, m18-l05]
summary: Sort a singly linked list in O(n log n) by relinking its nodes. Merge sort fits lists better than arrays, because splitting and merging need no copies.
solutionFile: SortLinkedList.swift
testFile: SortLinkedListTests.swift
starter: |
  final class SortListNode {
      var value: Int
      var next: SortListNode?
      init(_ value: Int, next: SortListNode? = nil) {
          self.value = value
          self.next = next
      }
  }

  func sortLinkedList(_ head: SortListNode?) -> SortListNode? {
      // Your solution
      return head
  }
time: O(n log n)
space: O(log n) for the recursion
edgeCases:
  - Empty list and a single node
  - Two nodes, in order and reversed
  - Already sorted, reversed, and all equal
  - Equal values, whose original order should be kept
askInterviewer:
  - May I relink the existing nodes, or must I build a new list?
  - Should equal values keep their original order?
  - How long can the list be? Is recursion depth a concern?
  - Can I copy the values into an array, sort it, and write them back?
hints:
  - Which sort from Module 18 doesn't need random access?
  - To split a list in half you need its middle. The fast and slow pointer lesson shows how to find it in one pass.
  - The merge of two sorted lists only relinks nodes. You did it in the linked lists lesson.
followUps:
  - Write the bottom-up version (merge runs of 1, then 2, then 4…) to use O(1) extra space.
  - Why is quicksort a worse fit for a singly linked list?
  - How would you merge k sorted lists? (A heap of the current heads, Module 19.)
rubric:
  - I chose merge sort and explained why it suits linked lists.
  - I found the first middle with slow and fast pointers and cut the list in two.
  - I merged by relinking nodes with a dummy head, taking from the left on ties.
  - I handled empty and one-node lists as the base case and gave O(n log n) time, O(log n) space.
codeStatus: tested
---

A reminders app keeps each list's reminders as a singly linked list of due times. Write `sortLinkedList(_:)` that sorts the list in ascending order **by relinking the existing nodes** (no new value nodes) and returns the new head. Equal values must keep their original relative order.

```swift
let head = SortListNode.list([42, 7, 19, 3])
SortListNode.values(sortLinkedList(head))  // [3, 7, 19, 42]

SortListNode.values(sortLinkedList(SortListNode.list([5, -1, 5, 0])))  // [-1, 0, 5, 5]
sortLinkedList(nil)  // nil
```

`SortListNode.list(_:)` and `SortListNode.values(_:)` are helpers that build a list from an array and read it back.

**Constraints:** `0 ≤` number of nodes `≤ 5 · 10^4`; `-10^6 ≤ value ≤ 10^6`.

<!-- reveal -->

## First approach

Most fast sorts rely on jumping to any index in O(1), which a linked list can't do. Merge sort doesn't: it splits in half, sorts each half, and merges by walking both halves from the front. On a list, the split is "find the middle and cut one link" and the merge is relinking, so it needs no extra buffer, which is better than merge sort on arrays.

## Naive solution

Insertion sort, the list version: take nodes one at a time and insert each into a growing sorted list by walking it from the front:

```swift
func sortLinkedList(_ head: SortListNode?) -> SortListNode? {
    let dummy = SortListNode(0)
    var node = head
    while let current = node {
        node = current.next
        var spot = dummy
        while let candidate = spot.next, candidate.value <= current.value {
            spot = candidate
        }
        current.next = spot.next
        spot.next = current
    }
    return dummy.next
}
```

## Problems with the naive solution

Each insertion walks the sorted part: **O(n²)** in general, about 1.25 · 10^9 steps for 5 · 10^4 nodes. Here it's O(n) only for input sorted in **descending** order, because each node then belongs at the front. (Copying the values into an array, sorting it and writing them back is O(n log n), but it uses O(n) memory and moves values instead of nodes, which the problem rules out.)

## Optimized solution

Top-down merge sort. A list of zero or one node is sorted. Otherwise, walk `slow` one node and `fast` two nodes at a time to find the end of the first half, cut the link after it, sort both halves recursively, and merge them with a dummy head.

## Line by line

- `guard let head, head.next != nil else { return head }`: the base case, empty or one node.
- `var slow = head` and `var fast = head`, then `while let step = fast.next?.next`: `fast` moves two nodes while two more exist. That stops `slow` at the **first** middle, so for two nodes the halves are one and one, and the recursion always shrinks. Stopping at the second middle would split a two-node list into two and zero, forever.
- `slow = slow.next!`: safe, because `fast` is at least one step ahead of `slow` when there's a next-next node.
- `let secondHalf = slow.next` and `slow.next = nil`: cut the list into two independent lists.
- `return sortLinkedListMerge(sortLinkedList(head), sortLinkedList(secondHalf))`: sort each half, then merge.
- In the merge, `let dummy = SortListNode(0)` and `var tail = dummy`: the dummy means attaching the first node needs no special case.
- `while let a = first, let b = second`: while both lists have nodes.
- `if a.value <= b.value`: `<=` takes from the first list on ties, which keeps equal values in their original order: the sort is stable.
- `tail.next = first ?? second`: at most one list has nodes left, already sorted and linked, so they're attached in one step.

## Common mistakes

- Finding the second middle, which loops forever on two-node lists.
- Forgetting `slow.next = nil`, so the "first half" still runs to the end of the list.
- Using `<` in the merge, which makes the sort unstable.
- Copying values into new nodes instead of relinking, which the problem forbids and which costs O(n) memory.

## Variation

**Bottom-up merge sort:** no recursion. Walk the list merging pairs of runs of length 1, then 2, then 4, until one run covers the list. It's the same O(n log n) time with O(1) extra space, at the cost of more pointer bookkeeping: each pass must cut runs off, merge them, and stitch the result back onto the tail of what's done.
