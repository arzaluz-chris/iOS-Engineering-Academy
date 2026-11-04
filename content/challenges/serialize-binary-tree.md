---
id: serialize-binary-tree
title: Serialize and Deserialize Binary Tree
difficulty: hard
order: 73
patterns: [Binary tree, Preorder, Explicit stack, Parsing]
prerequisites: [m17-l01, m19-l01]
summary: Turn a tree into a string and back, exactly. The design decision is what to write for missing children; the implementation decision is how to avoid recursion on deep trees.
solutionFile: SerializeBinaryTree.swift
testFile: SerializeBinaryTreeTests.swift
starter: |
  final class CodecTreeNode {
      var value: Int
      var left: CodecTreeNode?
      var right: CodecTreeNode?
      init(_ value: Int, _ left: CodecTreeNode? = nil, _ right: CodecTreeNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func serializeTree(_ root: CodecTreeNode?) -> String {
      // Your solution
      return ""
  }

  func deserializeTree(_ text: String) -> CodecTreeNode? {
      // Your solution
      return nil
  }
time: O(n) each way
space: O(n) each way
edgeCases:
  - Empty tree
  - Negative and multi-digit values
  - A very deep chain (50,000 nodes)
  - Malformed text (too few or too many tokens, a token that isn't a number)
askInterviewer:
  - Do you need a specific format, or can I design one?
  - Can values be negative or have several digits?
  - How deep can the tree be?
  - What should deserializing do with text it didn't produce?
hints:
  - Preorder alone doesn't determine a tree. What's missing? Try writing a marker every time a child is absent.
  - With markers, can you read the string back one token at a time without knowing anything else? Each number opens a node; what does each marker close?
  - Recursion is the shortest way to write both directions. How deep can it go, and what would you replace it with?
followUps:
  - Make the output smaller. (Level order with trailing markers trimmed, or a binary format.)
  - For a binary search tree, preorder without any markers is enough. Why?
  - Why would you use Codable for this in an app, and what would the JSON look like for a deep tree?
rubric:
  - I chose a format with explicit markers for empty children and explained why it's unambiguous.
  - I handled negative and multi-digit values with a separator.
  - I gave O(n) time and space each way.
  - I discussed recursion depth on degenerate trees and avoided it, or explained when it's acceptable.
codeStatus: tested
---

An outliner app stores each document as a binary tree of blocks and needs to save it to disk as text and load it back. Design the format and write both directions:

- `serializeTree(_:)` turns a tree into a `String`.
- `deserializeTree(_:)` turns that string back into a tree with exactly the same shape and values.

Use preorder, comma-separated, with `#` for every missing child, so the expected outputs below can be checked. `deserializeTree` returns `nil` for `"#"` and for text that isn't a complete tree in this format.

```swift
// Trees are written in level order, with nil for a missing child.
//      1
//     / \
//    2   3
//       /
//      4
serializeTree([1, 2, 3, nil, nil, 4])  // "1,2,#,#,3,4,#,#,#"
deserializeTree("1,2,#,#,3,4,#,#,#")   // [1, 2, 3, nil, nil, 4]
serializeTree(nil)                     // "#"
deserializeTree("1,#")                 // nil: the right child of 1 is missing
```

**Constraints:** `0 ≤ number of nodes ≤ 10^5`; values fit in `Int`; the tree can be a chain.

<!-- reveal -->

## First approach

A traversal by itself isn't enough: `[1, 2]` (2 on the left) and `[1, nil, 2]` (2 on the right) both have preorder `1, 2`. What's lost is where the children are missing. If every node writes its value and then exactly two child slots, with `#` for an empty slot, the text says everything about the shape. Reading it back is mechanical: a number creates a node with two empty slots to fill, and a `#` fills a slot with nothing.

## Naive solution

A format some people reach for first: put each node at its index in a complete binary tree (children of `i` at `2i + 1` and `2i + 2`), with `#` in empty slots.

```swift
func serializeTreeByPosition(_ root: CodecTreeNode?) -> String {
    func height(_ node: CodecTreeNode?) -> Int {
        guard let node else { return 0 }
        return 1 + max(height(node.left), height(node.right))
    }
    var slots = [String](repeating: "#", count: (1 << height(root)) - 1)
    func place(_ node: CodecTreeNode?, _ slot: Int) {
        guard let node else { return }
        slots[slot] = String(node.value)
        place(node.left, 2 * slot + 1)
        place(node.right, 2 * slot + 2)
    }
    place(root, 0)
    return slots.joined(separator: ",")
}
```

Deserializing reads slot `i` and recurses into `2i + 1` and `2i + 2`; the full version is in the solution file below as `deserializeTreeByPosition`.

## Problems with the naive solution

The array has 2^h − 1 slots, where h is the height. That's fine for a balanced tree, but a chain of 40 nodes needs over a trillion slots, and at 63 levels computing `(1 << height) - 1` overflows `Int` and traps. The format's size depends on the shape rather than on the number of nodes. Writing `#` only for the children that are actually missing keeps it at 2n + 1 tokens for n nodes.

## Optimized solution

Preorder with `#` markers, written and read with explicit stacks.

To serialize, pop a slot from a stack: write `#` if it's empty; otherwise write the value and push the right child, then the left, so the left comes out first.

To deserialize, keep a stack of nodes whose children are still being read, each with how many of its two slots are filled. Each token fills the next slot of the node on top: the left slot first, then the right, after which the node is done. If the token is a number, its new node goes on top of the stack, because its subtree comes next in preorder. At the end, every slot must be filled and every token used.

## Line by line

- `serializeTree`: `pending` holds `CodecTreeNode?`, so empty slots go on the stack too and come out as `#`.
- `pending.append(node.right)` then `pending.append(node.left)`: a stack is last in, first out, so pushing right first makes left come out first, which is preorder.
- `tokens.joined(separator: ",")`: one string at the end, instead of repeated `+=` on a growing string.
- `text.split(separator: ",", omittingEmptySubsequences: false)`: keeps empty tokens so that malformed text like `"1,,#"` fails `Int(token)` instead of being silently accepted.
- `guard let first = tokens.first, first != "#", let rootValue = Int(first) else { return nil }`: an empty tree, or text that doesn't start with a number.
- `var open: [(node: CodecTreeNode, filled: Int)]`: nodes with slots left to fill.
- `guard let (parent, filled) = open.popLast() else { return nil }`: more tokens than slots means malformed text.
- `if filled == 0 { parent.left = child; open.append((parent, 1)) } else { parent.right = child }`: the left slot first; after the right slot, the parent leaves the stack for good.
- `if let child { open.append((child, 0)) }`: a new node's subtree comes next in preorder, so it goes on top.
- `return open.isEmpty ? root : nil`: leftover open slots mean the text ended too early, like `"1,#"`.

## Common mistakes

- Leaving out the markers, so different shapes produce the same string.
- Writing values with no separator, so `1` followed by `23` reads as `12` followed by `3`.
- Recursing in both directions without considering depth. A chain of 10^5 nodes is 10^5 nested calls, and a background thread's stack is much smaller than the main thread's. (Releasing such a chain can recurse too, through each node's `deinit`.)
- Calling `Int(token)!` and crashing on malformed input.

## Variation

**Serialize a binary search tree:** preorder with no markers is enough, because the values themselves say where each node goes. Rebuild by inserting in preorder, or in O(n) by passing down the allowed range for each subtree.
