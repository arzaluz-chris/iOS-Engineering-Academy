---
id: diameter-of-binary-tree
title: Diameter of Binary Tree
difficulty: easy
order: 65
patterns: [Binary tree, Postorder, Return one value, track another]
prerequisites: [m18-l01, m19-l01]
summary: The longest path between any two nodes. The trick is a recursive helper that returns one thing (height) while recording another (the best path so far).
solutionFile: DiameterOfBinaryTree.swift
testFile: DiameterOfBinaryTreeTests.swift
starter: |
  final class DiameterTreeNode {
      var value: Int
      var left: DiameterTreeNode?
      var right: DiameterTreeNode?
      init(_ value: Int, _ left: DiameterTreeNode? = nil, _ right: DiameterTreeNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func diameterOfBinaryTree(_ root: DiameterTreeNode?) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(h) on the call stack, where h is the height
edgeCases:
  - Empty tree and a single node, both 0
  - The longest path doesn't pass through the root
  - A chain, where the diameter is the number of nodes minus one
askInterviewer:
  - Do you count edges or nodes on the path?
  - Does the path have to go through the root?
  - What should an empty tree return?
hints:
  - Any path in a tree has one highest node, where it turns from going up to going down. If that node is `x`, how long can the path be, in terms of its subtrees?
  - The longest path that bends at `x` goes down the left subtree as far as possible and down the right as far as possible. You already know a function from the binary trees lesson in Module 19 that measures "as far as possible".
  - Computing that function separately for every node repeats work. Can one postorder pass compute heights and update the best answer at the same time?
followUps:
  - Return the two endpoints of the longest path, not just its length.
  - Find the diameter of a general tree (any number of children per node) or of an unweighted tree given as an edge list. (Two BFS passes, or the same postorder idea keeping the two largest child heights.)
  - What changes if edges have weights?
rubric:
  - I saw that every path bends at one highest node, and that the best path through a node is left height + right height + 2.
  - I computed heights and the diameter in a single postorder pass.
  - I didn't assume the path goes through the root.
  - I gave O(n) time and O(h) space, and explained why the naive version is slower.
codeStatus: tested
---

A file-sync service models its replicas as a binary tree, and a change has to travel along tree edges from one replica to another. The worst case is the two replicas farthest apart.

Write `diameterOfBinaryTree(_:)`, which returns the number of **edges** on the longest path between any two nodes. The path can start and end anywhere; it doesn't have to go through the root.

```swift
// Trees are written in level order, with nil for a missing child.
//        1
//       / \
//      2   3
//     / \
//    4   5
diameterOfBinaryTree([1, 2, 3, 4, 5])  // 3: the path 4 → 2 → 1 → 3 (or 5 → 2 → 1 → 3)
diameterOfBinaryTree([1, 2])           // 1
diameterOfBinaryTree([7])              // 0
diameterOfBinaryTree([])               // 0
```

**Constraints:** `0 ≤ number of nodes ≤ 10^4`.

<!-- reveal -->

## First approach

Take the longest path and look at its highest node. From there, the path goes down into the left subtree as far as it can, and down into the right subtree as far as it can. In terms of heights (edges to the deepest leaf, with -1 for an empty subtree), the path has `height(left) + 1 + height(right) + 1` edges. The diameter is the largest of those values over all nodes.

## Naive solution

Apply that definition literally: at every node, compute both heights from scratch.

```swift
func diameterOfBinaryTree(_ root: DiameterTreeNode?) -> Int {
    func height(_ node: DiameterTreeNode?) -> Int {
        guard let node else { return -1 }
        return 1 + max(height(node.left), height(node.right))
    }
    guard let root else { return 0 }
    let throughRoot = height(root.left) + height(root.right) + 2
    return max(throughRoot,
               diameterOfBinaryTree(root.left),
               diameterOfBinaryTree(root.right))
}
```

## Problems with the naive solution

`height` walks the whole subtree it's given, and it's called once for every ancestor of each node. A node at depth d is measured d times. That's O(n · h) overall: O(n log n) on a balanced tree, O(n²) on a chain. The heights of the children are exactly what the parent needs, and they get thrown away.

## Optimized solution

Compute heights bottom-up once, in postorder, and while you're at each node, update the best diameter seen so far with `leftHeight + rightHeight + 2`. The recursive helper returns the height (what the parent needs) and records the diameter in a variable outside it (what you need at the end).

## Line by line

- `var longest = 0`: the best path length found so far. Starting at 0 covers the empty tree and the single node.
- `func height(_ node:) -> Int`: a nested function. It captures `longest` and can change it, because nested functions capture variables by reference.
- `guard let node else { return -1 }`: an empty subtree has height -1, so a leaf gets `1 + max(-1, -1) = 0`.
- `let leftHeight = height(node.left)` and `rightHeight`: postorder, children first.
- `longest = max(longest, leftHeight + rightHeight + 2)`: the longest path that bends here. The `+ 2` counts the two edges from this node down to its children; with -1 for a missing child it still comes out right (a leaf gives `-1 + -1 + 2 = 0`).
- `return 1 + max(leftHeight, rightHeight)`: the height, for the parent.
- `_ = height(root)`: run it for its side effect on `longest`; the root's height itself isn't the answer.

## Common mistakes

- Returning `height(root.left) + height(root.right) + 2` at the root only. In the tree `[1, 2, nil, 3, 4, …]` where everything hangs off the left child, the longest path bends below the root.
- Mixing up edges and nodes. If you count nodes, a single node has diameter 1; this problem counts edges, so it's 0.
- Using 0 for an empty subtree's height and then forgetting to adjust the `+ 2`.

## Variation

**Binary Tree Maximum Path Sum** (challenge 72) has exactly the same shape: every path bends at one node, a helper returns the best straight-down value, and a variable outside tracks the best bent path. The difference is that values can be negative, so a branch is sometimes better left out.
