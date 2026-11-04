---
id: intersection-of-two-lists
title: Intersection of Two Linked Lists
difficulty: easy
order: 33
patterns: [Linked list, Two pointers, Identity comparison]
prerequisites: [m17-l03, m17-l04, m10-l01]
summary: Find the commit where two branches' histories meet. Two pointers that switch lists when they run out arrive at the shared node together.
solutionFile: IntersectionOfLists.swift
testFile: IntersectionOfListsTests.swift
starter: |
  final class IntersectionListNode {
      let value: Int
      var next: IntersectionListNode?

      init(_ value: Int, next: IntersectionListNode? = nil) {
          self.value = value
          self.next = next
      }
  }

  func intersectionNode(_ first: IntersectionListNode?, _ second: IntersectionListNode?) -> IntersectionListNode? {
      // Your solution
      return nil
  }
time: O(n + m)
space: O(1)
edgeCases:
  - No shared nodes, even when the values are equal
  - One or both lists empty
  - The same list passed twice
  - One list is the tail of the other
  - Only the last node is shared
askInterviewer:
  - Does "intersect" mean the same node, or nodes with equal values?
  - Can the lists have cycles?
  - May I modify the lists temporarily, or must they stay untouched?
  - Do you know the lengths in advance?
hints:
  - Once two lists share a node, they share everything after it. So the shared part is a common tail. What does that say about where the lists differ?
  - If both lists had the same length before the shared part, walking them in step would make the pointers meet. How could you even out the lengths?
  - "When a pointer reaches the end of its list, send it to the head of the other list. How many nodes has each pointer walked when they meet?"
followUps:
  - How would you solve it by counting the two lengths first? Which version would you rather explain in an interview?
  - What if either list could contain a cycle?
  - How does git find a merge base when commits can have two parents? (It's a graph problem then, not a list problem.)
rubric:
  - I compared nodes by identity with ===, not by value.
  - I explained why the shared part is always a tail.
  - I equalized the path lengths, either by switching heads or by skipping the length difference.
  - I handled the no-intersection case and showed the loop terminates.
codeStatus: tested
---

A git client shows two branches. Each commit points to its parent, so a branch is a singly linked list from its tip back to the first commit, and two branches that forked from the same commit share every node from that commit back. Write `intersectionNode(_:_:)` that returns the first node the two lists **share** (the same node instance, not just an equal value), or `nil` if they share none. Don't modify the lists.

In the examples, `makeList(_:then:)` is a test helper that builds nodes for the values and links the last one to an existing list.

```swift
let shared = makeList([30, 40, 50])                 // the common history
let feature = makeList([7, 8], then: shared)        // 7 → 8 → 30 → 40 → 50
let main = makeList([1, 2, 3, 4], then: shared)     // 1 → 2 → 3 → 4 → 30 → 40 → 50
intersectionNode(feature, main) === shared          // true: the node holding 30

intersectionNode(makeList([1, 2, 3]), makeList([1, 2, 3]))   // nil: equal values, different nodes
```

**Constraints:** `0 ≤ n, m ≤ 3 · 10^4`; the lists have no cycles.

<!-- reveal -->

## First approach

Each node has one `next`, so once the two lists reach a common node, they continue through the same nodes to the end: the shared part is a **tail**. The lists only differ in their unshared prefixes, of lengths a and b. If a and b were equal, two pointers moving in step would land on the shared node at the same moment. The work is getting rid of the difference between a and b.

## Naive solution

For every node of the first list, walk the whole second list looking for that exact node:

```swift
func intersectionNode(_ first: IntersectionListNode?, _ second: IntersectionListNode?) -> IntersectionListNode? {
    var a = first
    while let nodeA = a {
        var b = second
        while let nodeB = b {
            if nodeA === nodeB {
                return nodeA
            }
            b = nodeB.next
        }
        a = nodeA.next
    }
    return nil
}
```

## Problems with the naive solution

It's **O(n · m)**: with two 30,000-commit histories, up to 9 · 10^8 comparisons. A `Set<ObjectIdentifier>` of the first list's nodes would bring it to O(n + m) but uses O(n) extra memory. The common-tail shape lets you do it with two pointers and no memory at all.

## Optimized solution

Start pointer `a` at the first list and `b` at the second. Step both one node at a time. When `a` falls off the end, send it to the head of the **second** list; when `b` falls off, send it to the head of the **first**. Call the unshared lengths a and b and the shared length c. Pointer `a` walks a + c nodes, then b more to reach the shared node again: a + c + b. Pointer `b` walks b + c, then a: b + c + a. The same number, so they arrive at the shared node together. With no shared node (c = 0), both reach `nil` together after a + b steps, and the loop ends there.

## Line by line

- `var a = first` and `var b = second`: the two walkers.
- `while a !== b`: identity, not equality. The loop ends when both point at the same node, or when both are `nil`, because `nil !== nil` is `false`.
- `a = a == nil ? second : a?.next`: step forward, or, after falling off the end, restart at the other list's head. Each pointer switches at most once before the loop ends.
- `b = b == nil ? first : b?.next`: the mirror image.
- `return a`: the shared node, or `nil`.

Each pointer walks at most n + m nodes plus the two `nil` steps: **O(n + m) time, O(1) space**. If one list is empty, its pointer starts at `nil`, switches to the other list on the first step, and the argument still holds with a length of 0.

## Common mistakes

- Comparing `value`s with `==`. Two branches can have commits with equal values that are different nodes. Use `===`.
- Switching the pointer to its **own** list's head when it runs out. Then the lengths never even out and the loop can run forever.
- Skipping the `nil` step: jumping straight from the last node to the other head. Then with no intersection the pointers never become `nil` at the same time and the loop never ends.
- Building a `Set` of values instead of node identities.

## Variation

**Count the lengths first**: walk both lists to get n and m, advance the longer list's pointer by |n − m|, then walk both in step until they're `===`. Same O(n + m) time and O(1) space, more lines, and some people find it easier to explain than the head switch.
