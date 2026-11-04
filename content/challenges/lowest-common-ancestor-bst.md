---
id: lowest-common-ancestor-bst
title: Lowest Common Ancestor in a BST
difficulty: medium
order: 68
patterns: [Binary search tree, Using the invariant]
prerequisites: [m19-l01, m19-l02]
summary: Find the deepest node above two values in a binary search tree. The general-tree answer visits every node; the BST ordering lets you walk a single path.
solutionFile: LowestCommonAncestorBST.swift
testFile: LowestCommonAncestorBSTTests.swift
starter: |
  final class BSTAncestorNode {
      var value: Int
      var left: BSTAncestorNode?
      var right: BSTAncestorNode?
      init(_ value: Int, _ left: BSTAncestorNode? = nil, _ right: BSTAncestorNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func lowestCommonAncestorInBST(_ root: BSTAncestorNode?, _ first: Int, _ second: Int) -> BSTAncestorNode? {
      // Your solution
      return nil
  }
time: O(h), where h is the height
space: O(1)
edgeCases:
  - One value is an ancestor of the other
  - Both values are the same node
  - The values come in either order
  - A degenerate tree (a chain), where h is n
askInterviewer:
  - Is the tree a binary search tree, or any binary tree?
  - Are both values guaranteed to be in the tree?
  - Can a node be its own ancestor? (Here it can.)
  - Are values distinct?
hints:
  - "Start at the root. If both values are smaller than the root, where must their common ancestor be?"
  - "Keep walking. What does it mean when one value is smaller than the current node and the other is larger?"
  - What if one of the values equals the current node?
followUps:
  - Solve it for a plain binary tree with no ordering. (Recursive search that reports what it found below; O(n).)
  - What if the values might not be in the tree?
  - Many queries on the same tree. How do you answer each one faster than O(h)? (Binary lifting or an Euler tour; mention them, no need to implement.)
rubric:
  - I used the BST ordering to decide which side to walk into.
  - I identified the split point as the answer, including when it equals one of the values.
  - I wrote it as a loop with O(1) extra space.
  - I gave O(h) time and explained that h is O(log n) only for a balanced tree.
codeStatus: tested
---

A company directory app stores employees in a binary search tree keyed by employee ID. For a permissions feature it needs the **lowest common ancestor** of two IDs: the deepest node that has both of them in its subtree. A node counts as part of its own subtree, so if one ID sits above the other, the higher one is the answer.

Write `lowestCommonAncestorInBST(_:_:_:)`. Values are distinct, both values are in the tree, and the function returns the node (or `nil` for an empty tree).

```swift
// Trees are written in level order, with nil for a missing child.
//            20
//          /    \
//        10      30
//       /  \    /  \
//      5   15  25   40
//         /  \
//        12  18
let directory = [20, 10, 30, 5, 15, 25, 40, nil, nil, 12, 18]
lowestCommonAncestorInBST(directory, 12, 18)?.value  // 15
lowestCommonAncestorInBST(directory, 5, 18)?.value   // 10
lowestCommonAncestorInBST(directory, 12, 40)?.value  // 20
lowestCommonAncestorInBST(directory, 10, 12)?.value  // 10: a node is its own ancestor
```

**Constraints:** `1 ≤ number of nodes ≤ 10^5`; values are distinct.

<!-- reveal -->

## First approach

Two values separate at some node: above it they're on the same side, and at it they go different ways (or one of them is the node itself). In a BST you can tell which side a value is on just by comparing it with the node. So you don't need to search the tree; you can walk straight down to the split.

## Naive solution

The answer for any binary tree, ignoring the ordering: search both subtrees, and let each call report the matching node it found below it.

```swift
func lowestCommonAncestorInBST(_ root: BSTAncestorNode?, _ first: Int, _ second: Int) -> BSTAncestorNode? {
    guard let root else { return nil }
    if root.value == first || root.value == second { return root }
    let fromLeft = lowestCommonAncestorInBST(root.left, first, second)
    let fromRight = lowestCommonAncestorInBST(root.right, first, second)
    if fromLeft != nil && fromRight != nil { return root }
    return fromLeft ?? fromRight
}
```

If both sides report something, this node is where they split. If only one side does, pass that result up.

## Problems with the naive solution

It visits up to every node: O(n) time, plus O(h) on the call stack. It's correct for any binary tree, which is worth saying, but the interviewer told you it's a BST, and not using that is the thing they're checking.

## Optimized solution

Start at the root. If both values are smaller than the node, the split is in the left subtree; if both are larger, it's in the right. Otherwise they split here, or one of them is this node, and either way this node is the answer. It's a single path from the root, so it's O(h), and a loop needs no extra memory.

## Line by line

- `var current = root`: the cursor walking down.
- `while let node = current`: stops if the tree is empty (which only happens on an empty tree, since both values exist).
- `if first < node.value && second < node.value`: both are in the left subtree, so their lowest common ancestor is too.
- `else if first > node.value && second > node.value`: both are on the right.
- `else { return node }`: one is smaller and the other larger, or one of them equals `node.value`. Both cases mean this is the lowest node above both. The order of the two arguments doesn't matter, because the conditions are symmetric.
- `return nil`: only reached for an empty tree.

## Common mistakes

- Writing `first < node.value || second < node.value` and going left when only one value is smaller.
- Forgetting the "equal" case, and walking past a node that is one of the values.
- Claiming O(log n) without qualification. On a degenerate BST (sorted inserts, as in the binary search trees lesson in Module 19), h is n.

## Variation

**Lowest common ancestor in a plain binary tree:** no ordering, so you can't choose a side. The naive solution above is the standard answer there, O(n). If you can store parent pointers, another option is to collect one node's ancestors in a set and walk up from the other until you hit one.
