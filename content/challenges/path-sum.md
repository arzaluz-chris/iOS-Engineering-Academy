---
id: path-sum
title: Root-to-Leaf Path Sum
difficulty: easy
order: 64
patterns: [Binary tree, Depth-first search, State passed down]
prerequisites: [m18-l01, m19-l01]
summary: Is there a path from the root to a leaf whose values add up to a target? The lesson on depth showed information flowing down a tree; here you use that to avoid storing any path.
solutionFile: PathSum.swift
testFile: PathSumTests.swift
starter: |
  final class PathSumNode {
      var value: Int
      var left: PathSumNode?
      var right: PathSumNode?
      init(_ value: Int, _ left: PathSumNode? = nil, _ right: PathSumNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func hasPathSum(_ root: PathSumNode?, _ target: Int) -> Bool {
      // Your solution
      return false
  }
time: O(n)
space: O(h) on the call stack, where h is the height
edgeCases:
  - Empty tree, even with target 0
  - A node with a single child (it isn't a leaf)
  - A single node
  - Negative values, so a partial sum past the target can still come back
askInterviewer:
  - Does the path have to end at a leaf, or can it stop at any node?
  - Does it have to start at the root?
  - Can values be negative?
  - What should an empty tree return?
hints:
  - At the root, the question "is there a path summing to target?" becomes a question about each child. With what new target?
  - When exactly is the answer `true`? Be precise about what a leaf is.
  - Can you stop early when the running sum passes the target? Think about negative values before you answer.
followUps:
  - Return every root-to-leaf path that hits the target, not just whether one exists. (Backtracking with a shared path array.)
  - Count paths that sum to the target when they can start and end at any node, as long as they go downward. (A prefix-sum dictionary, as in the subarray-sum problem.)
  - How would you write it without recursion?
rubric:
  - I passed the remaining target down instead of storing whole paths.
  - I checked the sum only at leaves, and defined a leaf as a node with no children.
  - I returned false for an empty tree.
  - I gave O(n) time and O(h) space.
codeStatus: tested
---

A hiking app stores a trail network as a binary tree: the trailhead is the root, each node is a segment with its length in minutes, and each leaf is a viewpoint where the trail ends. A hiker has exactly `target` minutes and wants a route from the trailhead to some viewpoint that takes exactly that long.

Write `hasPathSum(_:_:)`, which returns `true` if some path from the root to a **leaf** (a node with no children) has values that add up to `target`.

```swift
// Trees are written in level order, with nil for a missing child.
//        5
//      /   \
//     3     8
//    /     / \
//   2     4   1
let trail = [5, 3, 8, 2, nil, 4, 1]
hasPathSum(trail, 10)  // true:  5 + 3 + 2
hasPathSum(trail, 14)  // true:  5 + 8 + 1
hasPathSum(trail, 8)   // false: 5 + 3 stops at 3, which isn't a leaf
hasPathSum([], 0)      // false: an empty tree has no paths
```

**Constraints:** `0 ≤ number of nodes ≤ 5,000`; `-1,000 ≤ value ≤ 1,000`; `-10^6 ≤ target ≤ 10^6`.

<!-- reveal -->

## First approach

A path from the root to a leaf is the root plus a path from one of its children to a leaf. So if the root's value is `v`, you need a path from a child that sums to `target - v`. That's the same problem, one level down, with a smaller target. The base case is a leaf: the answer is whether its value is exactly what's left.

## Naive solution

Collect every root-to-leaf path, then add each one up:

```swift
func hasPathSum(_ root: PathSumNode?, _ target: Int) -> Bool {
    var paths: [[Int]] = []
    func collect(_ node: PathSumNode?, _ path: [Int]) {
        guard let node else { return }
        let extended = path + [node.value]
        if node.left == nil && node.right == nil {
            paths.append(extended)
        }
        collect(node.left, extended)
        collect(node.right, extended)
    }
    collect(root, [])
    return paths.contains { $0.reduce(0, +) == target }
}
```

## Problems with the naive solution

Every call builds a new array with `path + [node.value]`, copying up to h values. Storing every path costs O(n · h) memory in total, and summing them costs as much time. On a balanced tree that's O(n log n); on a chain-like tree it's O(n²). None of it is needed: you never use a path again once you know its sum.

## Optimized solution

Carry a single number down instead of a path: how much is still left to reach the target. Each node subtracts its value. At a leaf, check whether nothing is left. The `||` stops as soon as one side finds a path.

## Line by line

- `guard let root else { return false }`: an empty subtree contains no path. This also handles the empty tree, so `hasPathSum([], 0)` is `false`.
- `let remaining = target - root.value`: what the rest of the path has to add up to.
- `if root.left == nil && root.right == nil`: a leaf. Only here can a path end.
- `return remaining == 0`: the path through this leaf hits the target exactly.
- `return hasPathSum(root.left, remaining) || hasPathSum(root.right, remaining)`: try the left side first; the right side is only explored if the left found nothing. A missing child returns `false` from the guard, so a node with one child only counts paths through the child it has.

## Common mistakes

- Checking `target == 0` when you reach `nil` instead of at a leaf. For the tree `[1, 2]` and a target of 1, the root's missing right child would report a path `[1]` that doesn't end at a leaf.
- Stopping early when the running sum exceeds the target. With negative values, `[10, -4, nil, -6]` hits 0 even though 10 overshoots it.
- Returning `true` for an empty tree with target 0.

## Variation

**Path Sum II:** return every root-to-leaf path that hits the target. Keep one `[Int]` path, append on the way down and `removeLast()` on the way back up, and copy it into the result only at a matching leaf. That's the backtracking pattern from Module 18.
