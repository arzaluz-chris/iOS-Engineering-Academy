---
id: copy-list-random-pointer
title: Copy List with Random Pointer
difficulty: medium
order: 38
patterns: [Linked list, Hash map from identity, Deep copy]
prerequisites: [m17-l03, m10-l01, m13, m16-l05]
summary: Deep-copy a linked list whose nodes also point at arbitrary other nodes. A dictionary keyed by node identity maps every original to its copy.
solutionFile: CopyRandomList.swift
testFile: CopyRandomListTests.swift
starter: |
  final class RandomListNode {
      let value: Int
      var next: RandomListNode?
      weak var random: RandomListNode?

      init(_ value: Int, next: RandomListNode? = nil) {
          self.value = value
          self.next = next
      }
  }

  func copyRandomList(_ head: RandomListNode?) -> RandomListNode? {
      // Your solution
      return nil
  }
time: O(n) on average
space: O(n)
edgeCases:
  - An empty list
  - random pointing at the node itself
  - random pointing backward, forward, or nil
  - Several nodes with equal values, so values can't identify nodes
  - The original list must be unchanged afterward
askInterviewer:
  - Can random point at any node in the list, including the node itself, or only at later nodes?
  - Can values repeat? (If so, a value can't stand in for a node.)
  - May I modify the original list temporarily?
hints:
  - Copying `next` is easy in one pass. What makes `random` harder?
  - When you copy a node's random link, you need "the copy of that node". Which data structure answers "what's the copy of X?" in O(1)?
  - "Class instances aren't Hashable by default. ObjectIdentifier(node) gives you a hashable key for a node's identity."
followUps:
  - Can you do it with O(1) extra space? (Weave each copy right after its original.)
  - Why is random declared weak here, and what would happen with a strong reference?
  - How would you deep-copy a general graph of objects, where any node can point at any number of others?
rubric:
  - I explained why a single pass can't set random, since the target's copy might not exist yet.
  - I mapped originals to copies by identity with ObjectIdentifier, not by value.
  - I built the copies first, then wired next and random in a second pass.
  - I made sure the copy shares no nodes with the original and that the original is unchanged.
codeStatus: tested
---

A form builder stores each form as a singly linked list of fields in tab order. Each field can also have a `random` link to another field of the same form that it depends on (a "confirm password" field points at "password"), or `nil`. Users can duplicate a form. Write `copyRandomList(_:)` that returns a **deep copy**: new nodes with the same values, where every `next` and `random` link points at the corresponding **new** node. No node of the copy may be a node of the original, and the original must be unchanged.

`random` is declared `weak`. It can point backward or at the node itself, and a strong reference there would form a reference cycle that ARC never frees (module 13). The `next` chain owns the nodes.

```swift
// Values in tab order, and the index each node's random points at.
// values:   [7,   13, 11, 10, 1]
// randoms:  [nil, 0,  4,  2,  0]
let copy = copyRandomList(original)
// copy has the same shape: values [7, 13, 11, 10, 1], randoms [nil, 0, 4, 2, 0],
// and none of its nodes is a node of `original`.
```

**Constraints:** `0 ≤ n ≤ 1000`; values can repeat; `random` is `nil` or points at a node of the same list.

<!-- reveal -->

## First approach

Copying the `next` chain is one pass. `random` is the hard part: when you copy node 2, its `random` might point at node 4, whose copy doesn't exist yet. Even when the copy exists, you need a way to get from "original node 4" to "copy of node 4". Values can't do it, because they repeat. What does is a dictionary from each original node's **identity** to its copy, filled in a first pass and read in a second.

## Naive solution

Copy the chain into an array, then for each original `random` find its target's position by walking from the head, and link to the copy at that position:

```swift
func copyRandomList(_ head: RandomListNode?) -> RandomListNode? {
    var originals: [RandomListNode] = []
    var current = head
    while let node = current {
        originals.append(node)
        current = node.next
    }
    let copies = originals.map { RandomListNode($0.value) }
    for index in copies.indices.dropLast() {
        copies[index].next = copies[index + 1]
    }
    for (index, original) in originals.enumerated() {
        guard let target = original.random else { continue }
        var position = 0
        var walker = head
        while let node = walker, node !== target {
            position += 1
            walker = node.next
        }
        copies[index].random = copies[position]
    }
    return copies.first
}
```

## Problems with the naive solution

Finding each `random` target's position is a walk from the head: **O(n²)** in total. It also needs `===` to find the node, because values repeat, which is the right instinct; it's just used n times over. A dictionary from identity to copy answers the same question in O(1) on average.

## Optimized solution

Two passes over the original list. The first creates a copy of every node, with the right value and no links yet, and records it in `[ObjectIdentifier: RandomListNode]`. The second sets each copy's `next` and `random` to the copies of the original's `next` and `random`, looked up in the dictionary. Return the copy of the head.

## Line by line

- `var copyOf: [ObjectIdentifier: RandomListNode] = [:]`: `ObjectIdentifier(node)` is a hashable value that's unique to a class instance while it's alive, so it works as a key for "this exact node" (a class has to opt in to be `Hashable` itself).
- First loop, `copyOf[ObjectIdentifier(node)] = RandomListNode(node.value)`: one copy per original. The dictionary holds the copies strongly, so they stay alive even though their `random` links will be weak.
- `current = head`: start the second pass.
- `let copy = copyOf[ObjectIdentifier(node)]`: the copy of the current node. It's always there; the lookup returns an optional, so the next two lines use `copy?.`.
- `copy?.next = node.next.flatMap { copyOf[ObjectIdentifier($0)] }`: if the original has a `next`, link to its copy; `flatMap` turns a `nil` `next` into `nil` and avoids a nested optional.
- `copy?.random = node.random.flatMap { copyOf[ObjectIdentifier($0)] }`: the same for `random`. Pointing at itself works, because the copy's own entry is already in the dictionary.
- `return head.flatMap { copyOf[ObjectIdentifier($0)] }`: the copy of the head, or `nil` for an empty list. When the function returns, the dictionary goes away, and the copied list is held together by its `next` chain from the returned head.

Two passes of O(1) average dictionary work per node: **O(n) time on average, O(n) extra space** for the dictionary. The original is only read.

## Common mistakes

- Keying the dictionary by `value`. Two fields with equal values collapse into one copy.
- Setting `random` in the first pass, when the target's copy may not exist yet.
- Returning the original head, or linking a copy's `random` to an original node, which makes a "copy" that's partly shared. The tests check that no copied link leads back into the original.
- Making `random` strong. It works for the copy's correctness, but every list with a backward or self `random` link leaks.
- In the O(1)-space version, forgetting to restore the original's `next` links when separating the lists.

## Variation

**O(1) extra space by weaving**: insert each copy right after its original (`A → A' → B → B' → …`), so the copy of any node X is `X.next`. A second pass sets `copy.random = original.random?.next`. A third pass unweaves the two lists, restoring the original. The solution file includes this version as `copyRandomListInterleaved`, and the tests run it against the same cases.
