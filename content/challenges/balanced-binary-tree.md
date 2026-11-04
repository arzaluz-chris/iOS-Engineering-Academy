---
id: balanced-binary-tree
title: Balanced Binary Tree
difficulty: easy
order: 66
patterns: [Binary tree, Postorder, Early exit with optionals]
prerequisites: [m18-l01, m19-l01, m19-l02]
summary: Check that no node's subtrees differ in height by more than one. The naive version recomputes heights over and over; the good one returns "height or failure" in a single Int?.
solutionFile: BalancedBinaryTree.swift
testFile: BalancedBinaryTreeTests.swift
starter: |
  final class BalancedTreeNode {
      var value: Int
      var left: BalancedTreeNode?
      var right: BalancedTreeNode?
      init(_ value: Int, _ left: BalancedTreeNode? = nil, _ right: BalancedTreeNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func isBalancedTree(_ root: BalancedTreeNode?) -> Bool {
      // Your solution
      return false
  }
time: O(n)
space: O(h) on the call stack, where h is the height
edgeCases:
  - Empty tree (balanced)
  - Balanced at the root but not lower down
  - A height difference of exactly 1
  - A single node
askInterviewer:
  - Does balanced mean the condition holds at every node, or only at the root?
  - Is an empty tree balanced?
  - How deep can the tree be?
hints:
  - Checking only the root isn't enough. Can you draw a tree whose root has two subtrees of equal height and is still badly unbalanced?
  - A node is balanced if both subtrees are balanced and their heights differ by at most 1. What does the parent need to know from each child?
  - Return two things from one call, the height and whether the subtree is balanced. In Swift, one optional can carry both.
followUps:
  - Why does a BST's search time depend on this property? (The degenerate case in the Module 19 lesson on binary search trees.)
  - How do self-balancing trees like AVL trees keep this property after each insert?
  - Return the deepest unbalanced node instead of a Bool.
rubric:
  - I checked the condition at every node, not just the root.
  - I computed heights bottom-up so each node is visited once.
  - I stopped as soon as an imbalance was found.
  - I gave O(n) time and O(h) space and compared it with the O(n · h) top-down version.
codeStatus: tested
---

An app keeps an in-memory binary search tree for a list of contacts. The Module 19 lesson on binary search trees showed that a BST's operations slow down from O(log n) to O(n) when it degenerates into a chain, so the app runs a debug check after bulk imports: is the tree still height-balanced?

A tree is **height-balanced** when, at every node, the heights of the left and right subtrees differ by at most 1. Write `isBalancedTree(_:)`.

```swift
// Trees are written in level order, with nil for a missing child.
isBalancedTree([3, 9, 20, nil, nil, 15, 7])  // true
isBalancedTree([1, 2, nil, 3])               // false: 1's left subtree has height 1, its right -1
isBalancedTree([1, 2, 3, 4, nil, nil, 5, 6, nil, nil, 7])
// false: the root is fine (both subtrees have height 2), but 2 and 3 are not
isBalancedTree([])                           // true
```

**Constraints:** `0 ≤ number of nodes ≤ 5,000`.

<!-- reveal -->

## First approach

The definition is recursive: a tree is balanced if its two subtrees are balanced and their heights differ by at most 1. The empty tree is balanced. You need heights, and the Module 19 lesson on binary trees already has a height function.

## Naive solution

Check the root's two heights, then recurse into each child:

```swift
func isBalancedTree(_ root: BalancedTreeNode?) -> Bool {
    func height(_ node: BalancedTreeNode?) -> Int {
        guard let node else { return -1 }
        return 1 + max(height(node.left), height(node.right))
    }
    guard let root else { return true }
    return abs(height(root.left) - height(root.right)) <= 1
        && isBalancedTree(root.left)
        && isBalancedTree(root.right)
}
```

## Problems with the naive solution

`height` walks an entire subtree, and the recursion calls it again at every level below. A node at depth d has its height recomputed by each of its d ancestors, so the total is O(n · h). For a balanced tree, the case you're hoping for, that's O(n log n). The parent needs exactly the heights the children just computed, and the naive version throws them away.

## Optimized solution

Go bottom-up. A helper returns the height of a subtree when it's balanced, and `nil` as soon as anything inside it isn't. The parent unwraps both children's results; if either is `nil`, or the heights are too far apart, it returns `nil` too. Every node is visited once, and the first imbalance short-circuits everything above it.

## Line by line

- `func balancedHeight(_ node:) -> Int?`: the optional carries both answers. A number means "balanced, and this is its height"; `nil` means "not balanced".
- `guard let node else { return -1 }`: an empty subtree is balanced, with height -1.
- `guard let leftHeight = balancedHeight(node.left), let rightHeight = balancedHeight(node.right), abs(leftHeight - rightHeight) <= 1`: the conditions are checked in order. If the left subtree is unbalanced, the right one is never visited.
- `else { return nil }`: any failure propagates straight up.
- `return 1 + max(leftHeight, rightHeight)`: the height, for the parent.
- `return balancedHeight(root) != nil`: the whole tree is balanced if the root got a height.

## Common mistakes

- Checking the heights only at the root. The third example above passes that check and isn't balanced.
- Using `-1` as the "unbalanced" sentinel while also using `-1` as the height of an empty subtree. The optional avoids that collision; if you use a sentinel, pick one that can't be a height, like `Int.min`.
- Confusing balanced with complete or full. A balanced tree can have gaps on its last levels.

## Variation

**Minimum height BST:** given a sorted array, build a BST of minimum height. Take the middle element as the root and recurse on each half. The result is always balanced by this definition.
