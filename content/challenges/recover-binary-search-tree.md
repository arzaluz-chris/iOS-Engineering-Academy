---
id: recover-binary-search-tree
title: Recover Binary Search Tree
difficulty: medium
order: 70
patterns: [Binary search tree, Inorder traversal, Explicit stack]
prerequisites: [m19-l01, m19-l02]
summary: Two values in a BST were swapped by mistake. Find them and swap them back without changing the shape, using the fact that an inorder walk of a BST is sorted.
solutionFile: RecoverBinarySearchTree.swift
testFile: RecoverBinarySearchTreeTests.swift
starter: |
  final class RecoverBSTNode {
      var value: Int
      var left: RecoverBSTNode?
      var right: RecoverBSTNode?
      init(_ value: Int, _ left: RecoverBSTNode? = nil, _ right: RecoverBSTNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func recoverBinarySearchTree(_ root: RecoverBSTNode?) {
      // Your solution
  }
time: O(n)
space: O(h) for the stack, where h is the height
edgeCases:
  - The two swapped values are next to each other in sorted order (one drop in the inorder sequence)
  - They're far apart (two drops)
  - One of them is the root
  - A two-node tree
askInterviewer:
  - Exactly two values were swapped, never zero and never more?
  - Can I change node values, or do I have to relink nodes?
  - Are values distinct?
  - Is O(h) extra space acceptable, or do you want O(1)?
hints:
  - What does an inorder traversal of a valid BST look like? What does it look like after two values trade places?
  - Write out `1 2 3 4 5 6` and swap 2 and 5. Where does the sequence go down? Now swap 3 and 4 instead.
  - You don't need the whole sequence, only the previous node at each step.
followUps:
  - Do it in O(1) extra space. (Morris traversal threads the tree temporarily through right pointers.)
  - What if more than two values could be out of place?
  - How would you validate a BST using the same "previous value" idea?
rubric:
  - I used the fact that a BST's inorder sequence is strictly increasing.
  - I handled both the one-drop case and the two-drop case.
  - I kept only the previous node instead of materializing the whole sequence.
  - I swapped values, not nodes, and left the shape alone.
codeStatus: tested
---

A sync bug in a notes app swapped the values of two nodes in its binary search tree of note IDs. Everything else is correct: same shape, and every other node holds the right value. The tree no longer satisfies the BST property, so lookups for those two IDs fail.

Write `recoverBinarySearchTree(_:)`, which repairs the tree in place by swapping those two values back. Don't change the shape. Values are distinct and exactly two were swapped.

```swift
// Trees are written in level order, with nil for a missing child.
//   broken:     30              fixed:     20
//              /  \                       /  \
//            10    25                   10    25
//           /  \     \                 /  \     \
//          5   15     20              5   15     30
recoverBinarySearchTree([30, 10, 25, 5, 15, nil, 20])  // tree becomes [20, 10, 25, 5, 15, nil, 30]
recoverBinarySearchTree([20, 15, 30, 5, 10])           // tree becomes [20, 10, 30, 5, 15]
recoverBinarySearchTree([1, 2])                        // tree becomes [2, 1]
```

**Constraints:** `2 ≤ number of nodes ≤ 1,000`; values are distinct.

<!-- reveal -->

## First approach

An inorder walk of a valid BST produces the values in strictly increasing order; that's the property the BST lesson in Module 19 used for sorted output. If two values trade places, the sequence is sorted except at those two positions. Find them in the sequence and you've found the nodes.

## Naive solution

Copy the values out in inorder, sort them, and write them back in the same order:

```swift
func recoverBinarySearchTree(_ root: RecoverBSTNode?) {
    var nodes: [RecoverBSTNode] = []
    func collect(_ node: RecoverBSTNode?) {
        guard let node else { return }
        collect(node.left)
        nodes.append(node)
        collect(node.right)
    }
    collect(root)
    let sortedValues = nodes.map(\.value).sorted()
    for (node, value) in zip(nodes, sortedValues) {
        node.value = value
    }
}
```

## Problems with the naive solution

It's correct and short, which makes it a good first answer. It costs O(n log n) for the sort and O(n) memory for the array of nodes. But sorting ignores what you know: the sequence is already sorted except for two entries. You can find them in one pass.

## Optimized solution

Walk inorder and compare each node with the one before it. A swap creates "drops", places where the previous value is bigger than the current one:

- If the swapped values are far apart, like 2 and 5 in `1 2 3 4 5 6` → `1 5 3 4 2 6`, there are two drops: `5 > 3` and `4 > 2`. The first misplaced node is the bigger side of the first drop (5), and the second is the smaller side of the last drop (2).
- If they're neighbors in sorted order, like 3 and 4 → `1 2 4 3 5 6`, there's one drop, `4 > 3`, and its two sides are the two nodes.

Recording "first: the previous node of the first drop; second: the current node of every drop" handles both cases. Swap their values at the end.

## Line by line

- `var stack` and `var current = root`: the iterative inorder traversal from the binary trees lesson in Module 19.
- `while let node = current { stack.append(node); current = node.left }`: go as far left as possible, saving the path.
- `let node = stack.removeLast()`: the next node in inorder. The outer loop's condition guarantees the stack isn't empty here.
- `if let previous, previous.value > node.value`: a drop. `if let previous` is the Swift 5.7 shorthand for `if let previous = previous`.
- `if first == nil { first = previous }`: only the first drop sets `first`.
- `second = node`: every drop overwrites `second`, so after two drops it holds the smaller side of the last one, and after one drop the smaller side of that one.
- `previous = node; current = node.right`: move on.
- `(first.value, second.value) = (second.value, first.value)`: swap the values with a tuple assignment. The nodes, and so the shape, stay where they are.

## Common mistakes

- Setting `second` only on the second drop. When the swapped values are neighbors in sorted order, there's only one drop and `second` would stay `nil`.
- Comparing each node only with its children. The broken example above has `30 > 10` at the root, which looks fine locally; the problem is between 30 and nodes far below it.
- Swapping node objects (relinking) instead of values. It's much harder and the problem doesn't ask for it.

## Variation

**Validate a BST with a single "previous" variable:** the same inorder walk, returning `false` at the first drop. It's an alternative to the min/max bounds approach in the BST lesson in Module 19, with the same O(n) time.
