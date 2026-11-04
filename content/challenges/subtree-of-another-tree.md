---
id: subtree-of-another-tree
title: Subtree of Another Tree
difficulty: easy
order: 67
patterns: [Binary tree, Tree comparison, Serialization, String matching]
prerequisites: [m18-l01, m19-l01]
summary: Does a small tree appear, exactly, somewhere inside a bigger one? Start with Same Tree at every node, then turn both trees into token lists and search one inside the other.
solutionFile: SubtreeOfAnotherTree.swift
testFile: SubtreeOfAnotherTreeTests.swift
starter: |
  final class SubtreeNode {
      var value: Int
      var left: SubtreeNode?
      var right: SubtreeNode?
      init(_ value: Int, _ left: SubtreeNode? = nil, _ right: SubtreeNode? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func isSameSubtreeShape(_ first: SubtreeNode?, _ second: SubtreeNode?) -> Bool {
      // Your solution
      return false
  }

  func isSubtree(_ tree: SubtreeNode?, _ pattern: SubtreeNode?) -> Bool {
      // Your solution
      return false
  }
time: O(n · m) with Same Tree at every node; O(n + m) with serialization and KMP
space: O(h) for the first; O(n + m) for the second
edgeCases:
  - The pattern matches the top of a subtree but the subtree has more nodes below
  - Same values, different shape
  - Values that share digits, like 2 and 12
  - Empty pattern, empty tree, or both
askInterviewer:
  - Does the match have to include everything below the matching node, or can the bigger tree have extra descendants?
  - Is an empty pattern a subtree of every tree?
  - How big are the two trees? Is O(n · m) acceptable?
hints:
  - First write `isSameSubtreeShape`. When are two trees identical? Handle the case where one side is nil.
  - With that function, `isSubtree` is one more recursion. What's its cost when many nodes share the root's value?
  - "To go faster: write each tree as a list in preorder, including a marker for every missing child. Why is a subtree a contiguous block of that list? Why do you need the markers?"
followUps:
  - Explain why preorder without null markers isn't enough. (Different shapes can share a preorder.)
  - Could you hash each subtree instead, Merkle-tree style? What do you do about collisions?
  - Count how many times the pattern occurs, or find all duplicate subtrees in one tree.
rubric:
  - I wrote a correct Same Tree, including the nil cases.
  - I explained the O(n · m) cost of trying it at every node.
  - I explained why a serialization with null markers turns the problem into finding a block in a list.
  - I used a linear-time search (KMP) or explained what a naive search would cost.
codeStatus: tested
---

A design tool lets people save a group of nested components as a reusable template. To show "this template is used here", it needs to know whether a template's tree appears inside a screen's tree.

Write two functions:

- `isSameSubtreeShape(_:_:)` returns `true` if two trees have the same shape and the same value at every position.
- `isSubtree(_:_:)` returns `true` if some node of `tree`, together with **everything below it**, is identical to `pattern`. An empty pattern counts as a subtree of any tree.

```swift
// Trees are written in level order, with nil for a missing child.
//   tree:      3            pattern:   4
//             / \                     / \
//            4   5                   1   2
//           / \
//          1   2
isSubtree([3, 4, 5, 1, 2], [4, 1, 2])                          // true
isSubtree([3, 4, 5, 1, 2, nil, nil, nil, nil, 0], [4, 1, 2])   // false: 2 has a child 0 here
isSubtree([1, 2], [1, nil, 2])                                 // false: same values, different shape
isSubtree([1, 2], [])                                          // true
```

**Constraints:** `0 ≤ nodes in tree ≤ 10^4`; `0 ≤ nodes in pattern ≤ 10^3`; values fit in `Int`.

<!-- reveal -->

## First approach

Two trees are identical if both are empty, or both have a root with the same value and their left subtrees are identical and their right subtrees are identical. With that function, `pattern` is a subtree of `tree` if it's identical to `tree` itself or a subtree of one of its children.

## Naive solution

```swift
func isSubtree(_ tree: SubtreeNode?, _ pattern: SubtreeNode?) -> Bool {
    if isSameSubtreeShape(tree, pattern) { return true }
    guard let tree else { return false }
    return isSubtree(tree.left, pattern) || isSubtree(tree.right, pattern)
}
```

`isSameSubtreeShape` is the comparison from the first approach; it's in the solution file below.

## Problems with the naive solution

At every one of the n nodes of `tree`, the comparison can walk up to m nodes of `pattern` before it finds a difference. When most values are equal (picture a tree full of 1s and a pattern of 1s that differs only at the bottom), that's O(n · m). For an interview with small trees this answer is often accepted; say its cost and offer the faster idea.

## Optimized solution

Write each tree as a preorder list of tokens: the node's value, then its left subtree, then its right, with a `nil` token for every missing child. In preorder, the tokens of any subtree form one contiguous block. And because every node writes exactly two child slots, a complete tree's list can't be the beginning of a different tree's list, so if `pattern`'s tokens appear as a block starting at some node, that block is exactly that node's subtree. The problem becomes "does this list contain that list as a block?", and the Knuth–Morris–Pratt algorithm answers it in O(n + m).

KMP precomputes, for each prefix of the pattern, the length of the longest proper prefix that's also a suffix (`failure`). When a token doesn't match, the search falls back to that length instead of restarting, so it never moves backward in the haystack.

## Line by line

- `isSameSubtreeShape`: a `switch` on the pair. `(nil, nil)` is a match; `let (first?, second?)` binds both when neither is nil; `default` covers exactly one side being nil.
- `let needle = subtreePreorderTokens(pattern)`: an `[Int?]`. Using `nil` as the marker, and keeping values as `Int`, avoids the digit problem a string would have: in `"12"`, the text `"2"` appears, but the token `2` doesn't appear in `[12]`. An empty pattern becomes `[nil]`, which every list contains, so the empty pattern matches as the problem asks.
- `subtreePreorderTokens`: preorder with an explicit stack. It pushes the right child before the left so the left comes out first.
- First loop, building `failure`: `matched` is the length of the current prefix that's also a suffix. On a mismatch it falls back through `failure[matched - 1]`; on a match it grows by one.
- Second loop, the search: the same logic over `haystack`. When `matched == needle.count`, the whole pattern appeared as a block.
- `return false`: the haystack ended without a full match.

## Common mistakes

- Serializing without null markers. The trees `[1, 2]` and `[1, nil, 2]` both have preorder `1, 2`.
- Serializing to a string without separators, or with separators but searching for `"2"` inside `"12"`. Tokens or delimited strings with a leading separator avoid this.
- In Same Tree, comparing values before checking that both nodes exist.
- Forgetting that the subtree has to match all the way down: a pattern `[2]` is not a subtree of `[1, 2, 3, 4]`, because 2 has a child there.

## Variation

**Find Duplicate Subtrees:** return one root of every subtree shape that appears more than once in a single tree. Serialize each subtree in postorder, store the strings in a dictionary with a count, and report the ones that reach 2.
