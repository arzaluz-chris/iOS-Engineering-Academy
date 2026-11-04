---
id: zigzag-level-order
title: Zigzag Level Order Traversal
difficulty: medium
order: 69
patterns: [Binary tree, Breadth-first search, Level by level]
prerequisites: [m17-l02, m19-l01]
summary: Read a tree level by level, alternating direction on each level. Breadth-first search with one twist, and a chance to show you know where the reversal belongs.
solutionFile: ZigzagLevelOrder.swift
testFile: ZigzagLevelOrderTests.swift
starter: |
  final class ZigzagTreeNode {
      var value: Int
      var left: ZigzagTreeNode?
      var right: ZigzagTreeNode?
      init(_ value: Int, _ left: ZigzagTreeNode? = nil, _ right: ZigzagTreeNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func zigzagLevelOrder(_ root: ZigzagTreeNode?) -> [[Int]] {
      // Your solution
      return []
  }
time: O(n)
space: O(w) for the current and next level, where w is the widest level, plus the output
edgeCases:
  - Empty tree
  - A single node
  - Missing children in the middle of a level
  - A chain, where every level has one node
askInterviewer:
  - Which direction does the first level go?
  - Do you want the values grouped by level, or one flat list?
  - Can the tree be empty?
hints:
  - Start from the level order traversal in the Module 19 lesson on binary trees. What would you change to alternate directions?
  - Is it easier to change the order you visit children in, or to keep the visiting order and change how you record each level?
  - Reversing a level of k values costs O(k). What does that add up to over the whole tree?
followUps:
  - Produce the zigzag order without reversing any array. (Build each level from both ends, or fill an array by index from the back.)
  - Return the levels bottom-up instead of top-down.
  - Print each level's rightmost value, the view from the right.
rubric:
  - I used a breadth-first walk that processes one whole level at a time.
  - I kept the child order fixed and only reversed the recorded values on alternate levels.
  - I explained why the reversals add up to O(n) in total.
  - I handled the empty tree.
codeStatus: tested
---

A comments screen shows a thread as a binary tree of replies. A design experiment lays the replies out in rows, one row per depth, with the reading direction alternating to guide the eye: the first row left to right, the second right to left, and so on.

Write `zigzagLevelOrder(_:)`, which returns the values of each level, with even levels (counting from 0) read left to right and odd levels read right to left.

```swift
// Trees are written in level order, with nil for a missing child.
//          1
//        /   \
//       2     3
//      / \   / \
//     4   5 6   7
zigzagLevelOrder([1, 2, 3, 4, 5, 6, 7])          // [[1], [3, 2], [4, 5, 6, 7]]
zigzagLevelOrder([8, 3, nil, 1, 6, nil, nil, 4]) // [[8], [3], [1, 6], [4]]
zigzagLevelOrder([])                             // []
```

**Constraints:** `0 ≤ number of nodes ≤ 2,000`.

<!-- reveal -->

## First approach

The levels are the same as in an ordinary level order traversal; only the order of the values inside some levels changes. So the plan is a breadth-first walk that knows where each level starts and ends, plus a decision per level about direction.

## Naive solution

Without a queue, you can still get the levels: find the height, then for each depth walk the whole tree and collect the nodes at that depth.

```swift
func zigzagLevelOrder(_ root: ZigzagTreeNode?) -> [[Int]] {
    func height(_ node: ZigzagTreeNode?) -> Int {
        guard let node else { return 0 }
        return 1 + max(height(node.left), height(node.right))
    }
    func collect(_ node: ZigzagTreeNode?, depth: Int, target: Int, into values: inout [Int]) {
        guard let node else { return }
        if depth == target {
            values.append(node.value)
            return
        }
        collect(node.left, depth: depth + 1, target: target, into: &values)
        collect(node.right, depth: depth + 1, target: target, into: &values)
    }
    var result: [[Int]] = []
    for depth in 0..<height(root) {
        var values: [Int] = []
        collect(root, depth: 0, target: depth, into: &values)
        result.append(depth.isMultiple(of: 2) ? values : values.reversed())
    }
    return result
}
```

## Problems with the naive solution

Each level walks from the root down to that depth, so the nodes near the top are visited once per level below them. That's O(n · h) time: fine for a balanced tree, O(n²) for a chain. A breadth-first walk visits each node once.

## Optimized solution

Keep the current level in an array. For each level, record the values left to right and build the next level from the children, also left to right. Then append the values as they are on even levels and reversed on odd ones. Changing the order you queue children in is tempting, but it gets confusing fast; reversing the finished level is simpler and costs O(k) for a level of k nodes, which adds up to O(n) over the whole tree.

## Line by line

- `guard let root else { return [] }`: an empty tree has no levels.
- `var level = [root]`: the nodes of the current level, left to right. Using a fresh array per level, instead of one queue, makes the level boundaries obvious and avoids `removeFirst()`, which is O(n) on an array.
- `for node in level`: records each value and collects the children, left before right, into `nextLevel`.
- `result.count.isMultiple(of: 2) ? values : values.reversed()`: `result.count` is the index of the level being added. `values.reversed()` on an array returns a lazy reversed view; because the expected type is `[Int]`, Swift picks the overload that returns a new array.
- `level = nextLevel`: move down one level. The loop ends when a level has no children.

## Common mistakes

- Reversing the order you add children to the queue on odd levels, and then reading the next level in the wrong order. Try it on the four-level example by hand before committing to it.
- Using `queue.removeFirst()` on an array: O(n) per call, so O(n²) overall on a wide tree.
- Starting the first level right to left. Ask, or follow the examples.

## Variation

**Average of each level** or **largest value in each level:** the same level-by-level loop, recording one number per level instead of an array.
