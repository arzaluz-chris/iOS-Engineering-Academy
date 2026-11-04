---
id: invert-binary-tree
title: Invert Binary Tree
difficulty: easy
order: 63
patterns: [Binary tree, Tree traversal, Explicit stack]
prerequisites: [m18-l01, m19-l01]
summary: Mirror a tree so every left child becomes a right child. A five-line recursion, and a good place to talk about what recursion costs on a deep tree.
solutionFile: InvertBinaryTree.swift
testFile: InvertBinaryTreeTests.swift
starter: |
  final class InvertTreeNode {
      var value: Int
      var left: InvertTreeNode?
      var right: InvertTreeNode?
      init(_ value: Int, _ left: InvertTreeNode? = nil, _ right: InvertTreeNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func invertTree(_ root: InvertTreeNode?) -> InvertTreeNode? {
      // Your solution
      return nil
  }
time: O(n)
space: O(h) for the stack, where h is the height
edgeCases:
  - Empty tree
  - A single node
  - A chain where every node has only a left child
  - A very deep chain (100,000 nodes) that would overflow a recursive solution's call stack
askInterviewer:
  - Should I change the tree in place or return a new one?
  - How deep can the tree get? Is recursion safe?
  - Do I return the root, or is the function only called for its side effect?
hints:
  - Draw a three-level tree and its mirror image. What happened at the root? What happened at each child?
  - Swapping the root's two children isn't enough by itself, but if every node swaps its own two children, is the whole tree mirrored?
  - The order you visit nodes in doesn't matter, as long as you visit every one. Which traversal can you write without recursion?
followUps:
  - How would you check whether a tree is symmetric, a mirror of itself, without modifying it?
  - Return a mirrored copy and leave the original untouched. What does that cost in memory?
  - Where does mirroring show up in an app? (Laying out a view hierarchy for a right-to-left language.)
rubric:
  - I saw that swapping the children of every node mirrors the whole tree.
  - I handled the empty tree.
  - I gave O(n) time and O(h) space, and explained what h is for a balanced tree and for a chain.
  - I mentioned the recursion depth risk and showed how an explicit stack avoids it.
codeStatus: tested
---

A layout engine stores a screen's sections as a binary tree. To support right-to-left languages it needs the mirror image of that tree: at every node, what was on the left goes on the right and the other way around.

Write `invertTree(_:)`, which mirrors the tree in place and returns its root.

```swift
// Trees are written in level order, with nil for a missing child.
invertTree([4, 2, 7, 1, 3, 6, 9])  // [4, 7, 2, 9, 6, 3, 1]
invertTree([2, 1, 3])              // [2, 3, 1]
invertTree([1, 2, nil, 3])         // [1, nil, 2, nil, 3]
invertTree([])                     // []
```

**Constraints:** `0 ≤ number of nodes ≤ 10^5`. The tree can be any shape, including a chain as deep as it has nodes.

<!-- reveal -->

## First approach

Look at the mirror of a small tree. The root stays where it is. Its two subtrees trade places, and each of them is mirrored too. So the job at each node is the same small job: swap its two children. Do that at every node and the whole tree is mirrored.

## Naive solution

The recursion follows the definition directly:

```swift
func invertTree(_ root: InvertTreeNode?) -> InvertTreeNode? {
    guard let root else { return nil }
    let invertedLeft = invertTree(root.left)
    root.left = invertTree(root.right)
    root.right = invertedLeft
    return root
}
```

## Problems with the naive solution

It's O(n) time and correct, and in many interviews it's the expected answer. The cost to point out is space: O(h) stack frames, where h is the height. On a balanced tree that's about log₂ n, harmless. On a chain of 100,000 nodes it's 100,000 nested calls, and a thread's stack is fixed in size (secondary threads get much less than the main thread). That can crash. Saying this out loud, and offering the iterative version, is what separates a good answer from a correct one.

## Optimized solution

Keep the nodes still waiting to be processed in an array used as a stack. Pop a node, swap its children, push the children that exist. The order doesn't matter, because each swap only touches one node. The memory moves from the call stack to the heap, where there's plenty of it.

## Line by line

- `guard let root else { return nil }`: an empty tree mirrors to an empty tree.
- `var pending = [root]`: the stack of nodes whose children haven't been swapped yet.
- `while let node = pending.popLast()`: `popLast()` returns `nil` once the stack is empty, which ends the loop. Using `removeLast()` there would crash instead.
- `swap(&node.left, &node.right)`: the standard library's `swap` exchanges two variables. `node` is a `let`, but it's a class reference, so its properties can still change.
- `if let left = node.left { pending.append(left) }`: only real children go on the stack, so the loop never has to handle `nil`.
- `return root`: the same object that came in, now mirrored.

## Common mistakes

- Writing `root.left = invertTree(root.right)` and then `root.right = invertTree(root.left)` in the recursive version. By the second line, `root.left` already holds the new subtree, so the original left subtree is lost. Save one side in a constant first.
- Swapping only the root's children, which mirrors the top level and leaves everything below it as it was.
- Using `removeLast()` in the loop condition: it traps on an empty array.

## Variation

**Symmetric tree:** decide whether a tree is its own mirror. Compare two cursors that move in opposite directions: the left child of one with the right child of the other. Same O(n) time, and nothing gets modified.
