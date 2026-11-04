---
id: construct-binary-tree
title: Construct Binary Tree from Preorder and Inorder
difficulty: medium
order: 71
patterns: [Binary tree, Divide and conquer, Hash map for index lookup]
prerequisites: [m16-l05, m18-l01, m19-l01]
summary: Rebuild a tree from two of its traversals. Preorder tells you each root, inorder tells you what's on its left and right, and a dictionary turns an O(n²) recursion into O(n).
solutionFile: ConstructBinaryTree.swift
testFile: ConstructBinaryTreeTests.swift
starter: |
  final class BuildTreeNode {
      var value: Int
      var left: BuildTreeNode?
      var right: BuildTreeNode?
      init(_ value: Int, _ left: BuildTreeNode? = nil, _ right: BuildTreeNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func buildTree(preorder: [Int], inorder: [Int]) -> BuildTreeNode? {
      // Your solution
      return nil
  }
time: O(n)
space: O(n) for the dictionary, plus O(h) on the call stack
edgeCases:
  - Empty input
  - A single node
  - A chain to the left (inorder is preorder reversed)
  - A chain to the right (inorder equals preorder)
askInterviewer:
  - Are the values distinct? (Without that, the tree isn't uniquely determined.)
  - Can I assume the two arrays describe the same tree?
  - How large can n be? Is recursion depth a concern?
hints:
  - Where is the root in preorder? Where is it in inorder, and what's on each side of it there?
  - Once you know how many nodes are in the left subtree, which part of preorder belongs to it?
  - Searching inorder for each root costs O(n). What can you build once, up front, to make that O(1)?
followUps:
  - Rebuild from postorder and inorder instead. Which end of postorder holds the root?
  - Can you rebuild from preorder and postorder? (Not uniquely, unless every node has 0 or 2 children.)
  - Serialize a tree so that one traversal is enough to rebuild it. (Challenge 73.)
rubric:
  - I explained that preorder gives the root and inorder splits the remaining nodes into left and right subtrees.
  - I used a dictionary from value to inorder index instead of searching.
  - I used index ranges instead of copying subarrays.
  - I built the left subtree before the right, matching preorder's order.
codeStatus: tested
---

A crash reporter receives a view hierarchy from a device as two lists of view IDs: the order a preorder traversal visited them, and the order an inorder traversal visited them. The original tree wasn't sent, to save space. The dashboard needs to show it.

Write `buildTree(preorder:inorder:)`, which rebuilds the tree. Values are distinct, and both arrays come from the same tree.

```swift
// The result is written in level order, with nil for a missing child.
buildTree(preorder: [3, 9, 20, 15, 7], inorder: [9, 3, 15, 20, 7])  // [3, 9, 20, nil, nil, 15, 7]
buildTree(preorder: [1, 2], inorder: [1, 2])                        // [1, nil, 2]
buildTree(preorder: [], inorder: [])                                // nil
```

**Constraints:** `0 ≤ n ≤ 3,000`; `preorder.count == inorder.count`; values are distinct.

<!-- reveal -->

## First approach

The first value in preorder is the root. Find it in inorder: everything to its left in inorder is the left subtree, everything to its right is the right subtree. If the left subtree has k nodes, the k values after the root in preorder are the left subtree's preorder, and the rest are the right subtree's. Each half is the same problem, smaller.

## Naive solution

Do exactly that, with slices copied into new arrays:

```swift
func buildTree(preorder: [Int], inorder: [Int]) -> BuildTreeNode? {
    guard let rootValue = preorder.first,
          let split = inorder.firstIndex(of: rootValue)
    else { return nil }
    let node = BuildTreeNode(rootValue)
    node.left = buildTree(
        preorder: Array(preorder[1..<(1 + split)]),
        inorder: Array(inorder[..<split]))
    node.right = buildTree(
        preorder: Array(preorder[(1 + split)...]),
        inorder: Array(inorder[(split + 1)...]))
    return node
}
```

## Problems with the naive solution

`firstIndex(of:)` is a linear search, and every call copies its subarrays. On a balanced tree that adds up to O(n log n). On a chain, each level searches and copies almost the whole array, so it's O(n²) time and O(n²) total allocation.

## Optimized solution

Fix both costs. Build a dictionary from value to inorder index once, so finding the root is O(1). And instead of copying, pass the bounds of the current inorder range, plus one shared cursor into preorder. Because preorder lists a root, then its whole left subtree, then its whole right subtree, building the left subtree first and the right second consumes preorder in exactly the right order. Each node is created once with O(1) work: O(n).

## Line by line

- `var inorderIndex: [Int: Int]`: value to position in inorder. This is where distinct values matter.
- `var nextPreorder = 0`: the next root to use. The nested function captures and advances it.
- `func build(_ low: Int, _ high: Int)`: builds the subtree whose values occupy `inorder[low...high]`.
- `guard low <= high else { return nil }`: an empty range is an empty subtree.
- `let rootValue = preorder[nextPreorder]; nextPreorder += 1`: take the next root from preorder.
- `let split = inorderIndex[rootValue]!`: the force unwrap is safe because both arrays hold the same values; if they might not, use `guard let` and decide what to return.
- `node.left = build(low, split - 1)` then `node.right = build(split + 1, high)`: left first. Swapping these two lines would hand the right subtree the left subtree's roots.
- `return build(0, inorder.count - 1)`: for empty input this is `build(0, -1)`, which returns `nil`.

## Common mistakes

- Building the right subtree first, or computing the preorder ranges with an off-by-one, so the wrong values become roots.
- Using `firstIndex(of:)` inside the recursion and claiming O(n).
- Forgetting to ask about duplicates. With `[1, 1]` in both arrays, there are two different trees and no way to choose.

## Variation

**Postorder and inorder:** the root is the last value of postorder. Walk postorder from the end, and build the **right** subtree before the left, because reading postorder backward gives root, right, left.
