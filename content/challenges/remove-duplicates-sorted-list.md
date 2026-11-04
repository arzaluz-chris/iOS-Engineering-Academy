---
id: remove-duplicates-sorted-list
title: Remove Duplicates from a Sorted List
difficulty: easy
order: 32
patterns: [Linked list, In-place relinking]
prerequisites: [m17-l03, m10-l01]
summary: Drop repeated values from a sorted linked list by relinking the nodes you already have. Sorted means the repeats are always neighbors.
solutionFile: RemoveDuplicatesSortedList.swift
testFile: RemoveDuplicatesSortedListTests.swift
starter: |
  final class DedupListNode {
      var value: Int
      var next: DedupListNode?

      init(_ value: Int, next: DedupListNode? = nil) {
          self.value = value
          self.next = next
      }
  }

  func removeDuplicateNodes(_ head: DedupListNode?) -> DedupListNode? {
      // Your solution
      return head
  }
time: O(n)
space: O(1)
edgeCases:
  - An empty list and a single node
  - Every node has the same value
  - No duplicates at all
  - A run of three or more equal values, especially at the end
  - Negative values
askInterviewer:
  - Is the list sorted in non-decreasing order?
  - Do I keep one copy of each value, or remove every value that appears more than once?
  - Should I relink the existing nodes, or is building a new list fine?
hints:
  - In a sorted list, where are all the copies of a value?
  - For a node, compare it with the node right after it. If they're equal, what single assignment removes the second one?
  - After skipping a duplicate, don't move forward yet. The new next node might be another copy.
followUps:
  - Remove every value that appears more than once, keeping only the values that were unique. (Now the head can disappear, so use a dummy head.)
  - What if the list isn't sorted? (A Set of seen values, O(n) space, or sort first.)
  - The nodes you skip are freed by ARC. When would they not be?
rubric:
  - I compared each node only with its successor, relying on the sort.
  - I kept the current node in place while skipping a run of duplicates.
  - I relinked in place with O(1) extra space and returned the original head.
  - I handled the empty list without a special case that crashes.
codeStatus: tested
---

A reading app syncs bookmarks from two devices into one sorted linked list of page numbers, and the merge left repeats: `1 → 1 → 2 → 3 → 3 → 3 → 5`. Write `removeDuplicateNodes(_:)` that removes repeated values so each page appears once, keeping the **first** node of each run, and returns the head. Relink the existing nodes; don't build a new list.

In the examples, `makeList` is a test helper that builds a list from an array; it isn't part of the task.

```swift
removeDuplicateNodes(makeList([1, 1, 2, 3, 3, 3, 5]))   // 1 → 2 → 3 → 5
removeDuplicateNodes(makeList([4, 4, 4]))               // 4
removeDuplicateNodes(makeList([2, 6, 9]))               // 2 → 6 → 9
removeDuplicateNodes(nil)                               // nil
```

**Constraints:** `0 ≤ n ≤ 10^4`; the list is sorted in non-decreasing order; `-10^4 ≤ value ≤ 10^4`.

<!-- reveal -->

## First approach

Because the list is sorted, every copy of a value sits in one contiguous run. So you never need to remember values you've seen: a node is a duplicate exactly when it equals the node before it. Removing a node from a singly linked list means changing its predecessor's `next` (lesson m17-l03), and here the predecessor is the node you're standing on. The head is always the first of its run, so it's always kept and no dummy node is needed.

## Naive solution

Copy the values into an array, skip repeats, and build a fresh list:

```swift
func removeDuplicateNodes(_ head: DedupListNode?) -> DedupListNode? {
    var values: [Int] = []
    var current = head
    while let node = current {
        if values.last != node.value {
            values.append(node.value)
        }
        current = node.next
    }
    var newHead: DedupListNode? = nil
    for value in values.reversed() {
        newHead = DedupListNode(value, next: newHead)
    }
    return newHead
}
```

## Problems with the naive solution

It's O(n) time, which is fine, but it uses **O(n) extra space** and allocates a whole new set of nodes. Any other part of the app holding a reference to one of the original nodes still sees the old list with its duplicates. The task was to fix the list, not to make a corrected copy.

## Optimized solution

Walk the list with one pointer. At each node, while the next node has the same value, unlink it by pointing past it. When the next node is different (or there is none), move forward. Each node is either visited or skipped exactly once.

## Line by line

- `var current = head`: the walk starts at the head, which is always kept.
- `while let node = current`: the standard traversal; it stops at `nil`, so an empty list returns right away.
- `while let following = node.next, following.value == node.value`: the next node exists and repeats this value.
- `node.next = following.next`: skip it. The skipped node loses its only strong reference and ARC frees it.
- The inner loop runs again **without** moving `node`, because the new `node.next` might be another copy. That's what handles `3 → 3 → 3`.
- `current = node.next`: the next node now holds a different value (or is `nil`), so move to it.
- `return head`: the head never changes. `@discardableResult` lets callers ignore the return value, since the list is fixed in place.

Every node is looked at once, either as `node` or as a skipped `following`: **O(n) time, O(1) extra space**.

## Common mistakes

- Using `if` instead of an inner `while`, then advancing. With three equal values, the third survives.
- Advancing `current` after a removal, which skips checking the node that just moved up.
- Comparing `node.value` with `node.next!.value` without checking that `next` exists, which crashes at the tail.
- Using a `Set` to track seen values. It works, but it ignores the sort and costs O(n) space.

## Variation

**Keep only distinct values**: remove every value that appears more than once (`1 → 1 → 2 → 3 → 3 → 5` becomes `2 → 5`). Now the head itself can be removed, so put a dummy node in front (lesson m17-l03), keep a `previous` pointer to the last node you kept, and when a run of length two or more starts, link `previous` past the whole run.
