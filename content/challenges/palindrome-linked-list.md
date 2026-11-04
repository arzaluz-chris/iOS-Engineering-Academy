---
id: palindrome-linked-list
title: Palindrome Linked List
difficulty: easy
order: 34
patterns: [Fast and slow pointers, In-place reversal]
prerequisites: [m17-l03, m17-l04]
summary: Check whether a linked list reads the same both ways without copying it. Find the middle, reverse the back half, compare, and put it back.
solutionFile: PalindromeList.swift
testFile: PalindromeListTests.swift
starter: |
  final class PalindromeListNode {
      let value: Int
      var next: PalindromeListNode?

      init(_ value: Int, next: PalindromeListNode? = nil) {
          self.value = value
          self.next = next
      }
  }

  func isPalindromeList(_ head: PalindromeListNode?) -> Bool {
      // Your solution
      return false
  }
time: O(n)
space: O(1)
edgeCases:
  - An empty list and a single node, which are palindromes
  - Two nodes, equal and different
  - Odd and even lengths
  - A mismatch only in the middle pair
  - The list must look the same afterward as before
askInterviewer:
  - May I modify the list, as long as I restore it before returning?
  - Is O(n) extra memory acceptable, or do you want O(1)?
  - Could another thread read the list while I'm working on it?
hints:
  - With an array, you'd compare values[i] with values[n - 1 - i]. A singly linked list can't walk backward. Which half would you need to walk backward?
  - Lesson m17-l04 finds the middle in one pass. Lesson m17-l03 reverses a list in place. Combine them.
  - After comparing, reverse the second half again and reattach it, so the caller gets the list back unchanged.
followUps:
  - Is changing the list temporarily acceptable in a multithreaded app? What would you do instead?
  - How would you write a recursive version, and what does it cost in stack space?
  - How would you check a doubly linked list?
rubric:
  - I explained the O(n) space version first and why the interviewer might want better.
  - I found the end of the first half with fast and slow pointers.
  - I reversed the second half in place, compared, and restored it.
  - I handled odd lengths, where the middle node has nothing to match.
codeStatus: tested
---

A music app lets users build "mirror" playlists that sound the same played forward or backward, and stores each playlist as a singly linked list of track IDs. Write `isPalindromeList(_:)` that returns `true` if the values read the same in both directions. Use O(1) extra memory. You may change links while you work, but the list must be exactly as it was when the function returns.

In the examples, `makeList` is a test helper that builds a list from an array.

```swift
isPalindromeList(makeList([1, 2, 3, 2, 1]))   // true
isPalindromeList(makeList([4, 7, 7, 4]))      // true
isPalindromeList(makeList([1, 2, 3, 1]))      // false
isPalindromeList(nil)                         // true
```

**Constraints:** `0 ≤ n ≤ 10^5`; `0 ≤ value ≤ 10^6`.

<!-- reveal -->

## First approach

A palindrome compares the first value with the last, the second with the second-to-last, and so on. The front half is easy to walk; the back half needs to be walked backward, which a singly linked list can't do. But you can reverse the back half in place (lesson m17-l03), after finding where it starts with fast and slow pointers (lesson m17-l04). Then both halves can be walked forward side by side.

## Naive solution

Copy the values into an array and compare it with its reverse:

```swift
func isPalindromeList(_ head: PalindromeListNode?) -> Bool {
    var values: [Int] = []
    var current = head
    while let node = current {
        values.append(node.value)
        current = node.next
    }
    return values == values.reversed()
}
```

## Problems with the naive solution

It's O(n) time and correct, but it uses **O(n) extra space**: a copy of the whole playlist, and to compare with `==`, `values.reversed()` builds a second one. The problem asks for O(1).

## Optimized solution

Three steps. First, fast and slow pointers find the end of the first half: the middle node for odd lengths, the first of the two middle nodes for even lengths. Second, reverse everything after it and compare the reversed second half with the first half, node by node, until the second half runs out. Third, reverse the second half again and reattach it after the end of the first half, so the list is back to its original links.

## Line by line

- `guard let head else { return true }`: an empty list reads the same both ways.
- `var firstHalfEnd = head` and `var fast = head`: slow and fast start together.
- `while let step = fast.next, let secondStep = step.next, let nextSlow = firstHalfEnd.next`: fast can take two steps. Stopping when it can't leaves `firstHalfEnd` on the middle node (odd length) or the first middle (even length). The third binding always succeeds, since slow is behind fast; it just avoids a force unwrap.
- `let secondHalf = reversePalindromeHalf(firstHalfEnd.next)`: reverse the back half. `firstHalfEnd.next` still points at the old first node of the back half, which is now its last node, with `next == nil`.
- `while let rightNode = right, let leftNode = left`: walk both halves. The back half is never longer than the front, so `right` runs out first. For odd lengths, the middle node is never compared, which is correct: it matches itself.
- `if leftNode.value != rightNode.value { matches = false; break }`: a mismatch. The function doesn't return here, because the list still has to be restored.
- `firstHalfEnd.next = reversePalindromeHalf(secondHalf)`: reverse the back half again and reattach it.
- `reversePalindromeHalf` is the in-place reversal from lesson m17-l03: save `next`, point the node backward, move both pointers forward.

Finding the middle is n/2 steps, each reversal is n/2, and the comparison is at most n/2: **O(n) time, O(1) extra space**.

## Common mistakes

- Returning `false` as soon as a mismatch is found, which leaves the caller with a broken list.
- Splitting at the second middle for even lengths and then comparing the wrong pairs, or letting the front half run out first.
- Comparing nodes with `===` instead of comparing their values.
- Forgetting that between the reversals the front half's last node still points into the back half. That's what makes reattaching a single assignment.
- Calling a recursive solution O(1) space. The recursion uses O(n) call stack.

## Variation

**Twin sum**: for an even-length list, the "twin" of node i is node n − 1 − i. Return the largest value + twin value. It's the same three steps: find the middle, reverse the back half, walk both halves together, this time adding instead of comparing.
