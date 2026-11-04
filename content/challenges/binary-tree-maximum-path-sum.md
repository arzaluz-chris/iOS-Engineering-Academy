---
id: binary-tree-maximum-path-sum
title: Binary Tree Maximum Path Sum
difficulty: hard
order: 72
patterns: [Binary tree, Postorder, Return one value, track another]
prerequisites: [m18-l01, m19-l01]
summary: The largest sum along any path, where values can be negative and the path can start and end anywhere. Diameter's structure, plus the decision of when to leave a branch out.
solutionFile: BinaryTreeMaximumPathSum.swift
testFile: BinaryTreeMaximumPathSumTests.swift
starter: |
  final class MaxPathNode {
      var value: Int
      var left: MaxPathNode?
      var right: MaxPathNode?
      init(_ value: Int, _ left: MaxPathNode? = nil, _ right: MaxPathNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func maxPathSum(_ root: MaxPathNode) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(h) on the call stack, where h is the height
edgeCases:
  - Every value is negative (the answer is the largest single value, not 0)
  - The best path doesn't touch the root
  - The best path ends at an inner node, not a leaf
  - A single node
askInterviewer:
  - Can the path be a single node?
  - Does it have to go through the root, or end at leaves?
  - Can values be negative? Can the sums overflow?
hints:
  - Every path has one highest node where it bends. If you knew the best straight-down path from each child, what's the best path that bends at a given node?
  - A straight-down path from a child that sums to less than 0 only hurts. What should the parent do with it?
  - The helper returns the best straight-down sum, which can use only one child. The best bent path uses both. Keep the second one in a variable outside the helper.
followUps:
  - Return the path itself, not just its sum.
  - What if the path must go from leaf to leaf?
  - Compare this with Diameter of Binary Tree (challenge 65). What's the same, and what's different?
rubric:
  - I separated the value returned to the parent (one branch) from the value that updates the answer (both branches).
  - I dropped negative branches with max(0, …).
  - I initialized the answer so that an all-negative tree returns its largest value, not 0.
  - I gave O(n) time and O(h) space.
codeStatus: tested
---

A trip-planning app models a road network as a binary tree. Each node is a town with a score: positive if it's worth visiting, negative if it costs more than it gives (tolls, traffic). A road trip is a **path**: a sequence of towns where each one is connected to the next by a tree edge and no town repeats. It has at least one town, and it can start and end anywhere.

Write `maxPathSum(_:)`, which returns the highest total score of any path in a non-empty tree.

```swift
// Trees are written in level order, with nil for a missing child.
maxPathSum([2, 1, 3])                         // 6: 1 → 2 → 3
//       -8
//      /  \
//     9    20
//         /  \
//        15   7
maxPathSum([-8, 9, 20, nil, nil, 15, 7])      // 42: 15 → 20 → 7, skipping the root
maxPathSum([-2, -1, -5])                      // -1: the single best town
```

**Constraints:** `1 ≤ number of nodes ≤ 3 · 10^4`; `-1,000 ≤ value ≤ 1,000`.

<!-- reveal -->

## First approach

As in Diameter of Binary Tree, look at a path's highest node. The path goes down from there into the left subtree some distance, and into the right subtree some distance, or not at all. So for each node you want the best **straight-down** sum starting at each child. If that sum is negative, leave the branch out. The best path bending at the node is its value plus whatever the two branches contribute.

## Naive solution

Treat each node as the bend, and compute the best straight-down sum of each child from scratch:

```swift
func maxPathSum(_ root: MaxPathNode) -> Int {
    func gain(_ node: MaxPathNode?) -> Int {
        guard let node else { return 0 }
        return node.value + max(0, gain(node.left), gain(node.right))
    }
    var best = Int.min
    var pending = [root]
    while let node = pending.popLast() {
        best = max(best, node.value + max(0, gain(node.left)) + max(0, gain(node.right)))
        if let left = node.left { pending.append(left) }
        if let right = node.right { pending.append(right) }
    }
    return best
}
```

## Problems with the naive solution

Each call to `gain` walks a whole subtree, and every node's subtree is walked again for each of its ancestors. That's O(n · h): O(n log n) if the tree is balanced, O(n²) for a chain of 30,000 towns. The children's gains are exactly what the parent needs, so compute them once.

## Optimized solution

One postorder pass. The helper `gain` returns the best straight-down sum starting at a node, which can continue into **one** child at most, since a path can't fork. Along the way, it updates `best` with the path that bends at the node and uses **both** children. That split between what you return and what you record is the core of the problem.

## Line by line

- `var best = root.value`: start with a real path, the root alone. Starting at 0 would be wrong when every value is negative.
- `func gain(_ node:) -> Int`: the best sum of a path that starts at `node` and goes straight down (or stops at `node`).
- `guard let node else { return 0 }`: a missing child contributes nothing.
- `let leftGain = max(0, gain(node.left))`: if the best straight-down path from the left child is negative, don't take it. Same on the right.
- `best = max(best, node.value + leftGain + rightGain)`: the best path that bends here. It always includes `node.value`, so it's never an empty path.
- `return node.value + max(leftGain, rightGain)`: the parent can extend through only one side.
- `_ = gain(root)`: run it for its effect on `best`.

## Common mistakes

- Returning `node.value + leftGain + rightGain` to the parent. That's a path that forks, which isn't a path.
- Initializing the answer to 0, so `[-3]` returns 0, a path with no towns.
- Clamping the node's own value with `max(0, …)`. Only the children's contributions are optional; the bend node is always on the path.

## Variation

**Longest univalue path:** the longest path where every node has the same value. Same structure: the helper returns the longest straight-down run of equal values, and the answer combines both sides where the child's value matches.
