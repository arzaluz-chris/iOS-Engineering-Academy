---
id: m19-l02
title: Binary search trees
description: You learn the ordering invariant that makes a binary tree searchable, write search, insert and delete (including the two-children case), validate a tree with lower and upper bounds instead of checking only parents and children, answer "next value at or above x" queries, and see how sorted input turns a BST into an O(n) linked list, which is why balanced trees exist.
module: m19
order: 2
level: intermediate
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m19-l01]
objectives:
  - State the binary search tree invariant precisely, for whole subtrees and not only children.
  - Search for, insert and delete values in a BST, handling the leaf, one-child and two-children cases of delete.
  - Validate a BST by passing lower and upper bounds down the recursion.
  - Use the invariant for ordered queries such as minimum, maximum and the smallest value at or above x.
  - Explain why every operation is O(h), and why h becomes n when the input arrives sorted.
terms:
  - term: Binary search tree (BST)
    definition: A binary tree where, for every node, all values in its left subtree are smaller than the node's value and all values in its right subtree are larger.
  - term: Inorder successor
    definition: The node that comes right after a given node in inorder, which in a BST is the next larger value. For a node with a right subtree, it's the minimum of that subtree.
  - term: Degenerate tree
    definition: A tree where every node has at most one child, so it's a linked list with height n − 1.
  - term: Balanced tree
    definition: A tree whose height stays O(log n). Self-balancing BSTs such as AVL and red-black trees restructure themselves on insert and delete to keep that bound.
  - term: Ceiling
    definition: The smallest value in a set that is greater than or equal to a given value, if there is one.
mastery:
  - Decide whether a drawn tree is a valid BST, including violations deeper than one level.
  - Write search and insert for a BST, iteratively or recursively.
  - Write delete for all three cases using the inorder successor.
  - Validate a BST with bounds in O(n).
  - Write a ceiling (or floor) query that runs in O(h).
  - Explain how insertion order determines height, and when to use a sorted array instead.
resources: [swift-book-structures-classes, swift-optional, swift-array, swift-book-generics]
cards:
  - id: m19-l02-c1
    front: State the BST invariant.
    back: "For every node, every value in its left subtree is smaller than the node's value, and every value in its right subtree is larger. It's about whole subtrees, not just the direct children."
  - id: m19-l02-c2
    front: How do you delete a BST node that has two children?
    back: "Replace its value with its inorder successor (the minimum of its right subtree), then delete that successor from the right subtree. The successor has no left child, so that second delete is an easy case."
  - id: m19-l02-c3
    front: Why isn't checking left.value < node.value < right.value at every node enough to validate a BST?
    back: "A node deep in the left subtree can be larger than an ancestor higher up while still being fine relative to its own parent. Pass down a lower and an upper bound and check each node against both."
  - id: m19-l02-c4
    front: What happens if you insert 1, 2, 3, …, n into an empty BST?
    back: "Every value goes to the right of the previous one, so the tree is a chain of height n − 1. Search becomes O(n), and building it costs O(n²) in total."
  - id: m19-l02-c5
    front: What does inorder traversal of a BST produce?
    back: "The values in increasing order, in O(n). That's how you print a BST sorted, and a way to validate one: the inorder sequence must be strictly increasing."
---

## The idea in one sentence

A binary search tree keeps a **sorting rule at every node**, so finding a value is a walk from the root that discards one subtree at each step, and the speed of everything depends on how tall the tree is.

## The invariant

A **binary search tree** (BST) is a binary tree where, for **every** node:

- every value in its **left subtree** is smaller than the node's value, and
- every value in its **right subtree** is larger.

Here's the tree from the previous lesson again. Check node 6: its whole left subtree ({4}) is smaller and its whole right subtree ({7}) is larger. Check 8: everything on the left ({1, 3, 4, 6, 7}) is smaller and everything on the right ({10, 13, 14}) is larger.

```text
          8
        /   \
       3     10
      / \      \
     1   6      14
        / \    /
       4   7  13
```

The rule is about **subtrees**, not children. If you replaced 7 with 9, every parent-child pair would still look right (9 > 6), but 9 would sit in the left subtree of 8 while being larger than 8. That tree is not a BST, and searching it for 9 would go right at the root and miss it.

This lesson's trees hold distinct values. If you need duplicates, either store a count in each node or pick a side and stick to it (for example, equal values go right). Mixing the two breaks search.

The binary search of Module 16 discards half of a **sorted array** at each step. A BST does the same with a linked structure: at each node, the invariant tells you which subtree can contain the value, so you never look at the other one.

## Search

```swift
final class TreeNode {
    var value: Int
    var left: TreeNode?
    var right: TreeNode?
    init(_ value: Int, _ left: TreeNode? = nil, _ right: TreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

func contains(_ root: TreeNode?, _ target: Int) -> Bool {
    var current = root
    while let node = current {
        if target == node.value { return true }
        current = target < node.value ? node.left : node.right
    }
    return false
}

let root = TreeNode(8,
    TreeNode(3, TreeNode(1), TreeNode(6, TreeNode(4), TreeNode(7))),
    TreeNode(10, nil, TreeNode(14, TreeNode(13))))

print(contains(root, 7), contains(root, 13), contains(root, 5), contains(nil, 5))
```

```output
true true false false
```

Searching for 5: 5 < 8 go left, 5 > 3 go right, 5 < 6 go left, 5 > 4 go right, which is `nil`. Four comparisons, and not one of them looked at 10, 13 or 14. The loop follows a **single path** from the root, so it costs **O(h)** time, where h is the height, and O(1) space. A recursive version is just as short but uses O(h) stack for no benefit.

## Insert

A new value goes exactly where an unsuccessful search for it ends: at the `nil` where the search fell off the tree. The cleanest way to write that is a recursive function that **returns the root of the updated subtree**, so the parent can reattach it:

```swift
final class TreeNode {
    var value: Int
    var left: TreeNode?
    var right: TreeNode?
    init(_ value: Int, _ left: TreeNode? = nil, _ right: TreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

func insert(_ node: TreeNode?, _ value: Int) -> TreeNode {
    guard let node else { return TreeNode(value) }
    if value < node.value {
        node.left = insert(node.left, value)
    } else if value > node.value {
        node.right = insert(node.right, value)
    }
    return node
}

func inorder(_ node: TreeNode?, _ result: inout [Int]) {
    guard let node else { return }
    inorder(node.left, &result)
    result.append(node.value)
    inorder(node.right, &result)
}

var root: TreeNode? = nil
for value in [8, 3, 10, 1, 6, 14, 4, 7, 13, 6] {
    root = insert(root, value)
}

var sorted: [Int] = []
inorder(root, &sorted)
print(sorted)
print(root?.left?.right?.value ?? -1, root?.right?.right?.left?.value ?? -1)
```

```output
[1, 3, 4, 6, 7, 8, 10, 13, 14]
6 13
```

1. The base case creates the node. The caller stores the returned node in `left` or `right`, so the new leaf gets attached to the right parent without any "remember the parent" bookkeeping.
2. For a non-empty subtree, the function recurses into one side and then returns the same node, so reassigning `node.left = insert(node.left, value)` is a no-op except at the spot where the leaf is created.
3. The second 6 matches an existing node and isn't inserted. That's this tree's duplicate policy, chosen on purpose.
4. Inorder gives the sorted values, which is a quick check that every insert respected the invariant.

The tree came out identical to the drawing because the values were inserted in that order. **Insert order decides the shape**, which matters a lot below.

## Minimum, maximum and ordered queries

The smallest value is at the end of the left spine: keep going left until there's no left child. The largest is at the end of the right spine. Both are O(h).

The invariant also answers questions a hash set can't. Say a calendar keeps free appointment slots (minutes since midnight) in a BST and a user asks for the first slot at or after 10:00 (600). That's the **ceiling** of 600:

```swift
final class TreeNode {
    var value: Int
    var left: TreeNode?
    var right: TreeNode?
    init(_ value: Int, _ left: TreeNode? = nil, _ right: TreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

func insert(_ node: TreeNode?, _ value: Int) -> TreeNode {
    guard let node else { return TreeNode(value) }
    if value < node.value {
        node.left = insert(node.left, value)
    } else if value > node.value {
        node.right = insert(node.right, value)
    }
    return node
}

func minimum(_ root: TreeNode) -> Int {
    var node = root
    while let left = node.left { node = left }
    return node.value
}

func ceiling(_ root: TreeNode?, _ target: Int) -> Int? {
    var best: Int? = nil
    var current = root
    while let node = current {
        if node.value == target { return target }
        if node.value > target {
            best = node.value
            current = node.left
        } else {
            current = node.right
        }
    }
    return best
}

var slots: TreeNode? = nil
for minute in [660, 540, 780, 570, 615, 900] {
    slots = insert(slots, minute)
}
print(minimum(slots!))
print(ceiling(slots, 600) ?? -1, ceiling(slots, 615) ?? -1, ceiling(slots, 800) ?? -1, ceiling(slots, 901) ?? -1)
```

```output
540
615 615 900 -1
```

In `ceiling`, a node larger than the target is a **candidate**: it's at or above the target, but there may be a smaller one that still qualifies, and it can only be in the left subtree. So record it and go left. A node smaller than the target can't be the answer, nor can anything in its left subtree, so go right. The last candidate recorded is the smallest one, because each new candidate was found inside the previous candidate's left subtree. One path, O(h).

A sorted array with binary search answers the same query in O(log n), and in a Swift app that's usually what you'd write when the set changes rarely. A BST pays off when inserts and deletes are frequent **and** the tree stays balanced.

## Delete

Deleting is where the cases show up. Find the node, then:

1. **No children (a leaf)**: replace it with `nil`.
2. **One child**: replace it with that child. The child's whole subtree was already on the correct side of the parent, so the invariant still holds.
3. **Two children**: you can't just remove the node; both subtrees need a parent. Replace the node's **value** with its **inorder successor**, the smallest value in its right subtree, and then delete that successor from the right subtree. The successor is larger than everything on the left and smaller than everything else on the right, so it's a valid replacement. And it has no left child (otherwise that child would be smaller), so deleting it is case 1 or 2.

```swift
final class TreeNode {
    var value: Int
    var left: TreeNode?
    var right: TreeNode?
    init(_ value: Int, _ left: TreeNode? = nil, _ right: TreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

func delete(_ node: TreeNode?, _ value: Int) -> TreeNode? {
    guard let node else { return nil }
    if value < node.value {
        node.left = delete(node.left, value)
        return node
    }
    if value > node.value {
        node.right = delete(node.right, value)
        return node
    }
    guard let left = node.left else { return node.right }
    guard let right = node.right else { return left }
    var successor = right
    while let smaller = successor.left { successor = smaller }
    node.value = successor.value
    node.right = delete(right, successor.value)
    return node
}

func preorder(_ node: TreeNode?) -> String {
    guard let node else { return "-" }
    if node.left == nil && node.right == nil { return "\(node.value)" }
    return "\(node.value)(\(preorder(node.left)) \(preorder(node.right)))"
}

var root: TreeNode? = TreeNode(8,
    TreeNode(3, TreeNode(1), TreeNode(6, TreeNode(4), TreeNode(7))),
    TreeNode(10, nil, TreeNode(14, TreeNode(13))))

print(preorder(root))
root = delete(root, 13)
print(preorder(root))
root = delete(root, 10)
print(preorder(root))
root = delete(root, 3)
print(preorder(root))
root = delete(root, 99)
print(preorder(root))
```

```output
8(3(1 6(4 7)) 10(- 14(13 -)))
8(3(1 6(4 7)) 10(- 14))
8(3(1 6(4 7)) 14)
8(4(1 6(- 7)) 14)
8(4(1 6(- 7)) 14)
```

1. The first two branches walk down exactly like insert and reattach the updated subtree.
2. When the node is found, the two `guard` lines handle cases 1 and 2 at once: no left child means the right subtree (maybe `nil`) takes its place; no right child means the left subtree does.
3. Deleting 3 is case 3. Its right subtree is 6(4 7), whose minimum is 4. The node keeps its position but takes the value 4, and 4 is deleted from the right subtree, where it's a leaf.
4. Deleting 99, which isn't in the tree, walks down to `nil` and changes nothing.

Every case does one O(h) walk down (plus at most one more to find and delete the successor), so delete is **O(h)**.

> [!note] Using the predecessor instead
> The largest value in the left subtree, the **inorder predecessor**, works just as well for case 3. Some implementations alternate between the two to avoid always shrinking the same side.

## Validating a BST

A function that receives a tree from somewhere else (deserialized from disk, built by a teammate's code) may want to check the invariant. The tempting version compares each node with its children:

```swift
final class TreeNode {
    var value: Int
    var left: TreeNode?
    var right: TreeNode?
    init(_ value: Int, _ left: TreeNode? = nil, _ right: TreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

func looksValid(_ node: TreeNode?) -> Bool {
    guard let node else { return true }
    if let left = node.left, left.value >= node.value { return false }
    if let right = node.right, right.value <= node.value { return false }
    return looksValid(node.left) && looksValid(node.right)
}

func isValidBST(_ node: TreeNode?, above lower: Int? = nil, below upper: Int? = nil) -> Bool {
    guard let node else { return true }
    if let lower, node.value <= lower { return false }
    if let upper, node.value >= upper { return false }
    return isValidBST(node.left, above: lower, below: node.value)
        && isValidBST(node.right, above: node.value, below: upper)
}

let broken = TreeNode(8, TreeNode(3, TreeNode(1), TreeNode(9)), TreeNode(10))
let good = TreeNode(8, TreeNode(3, TreeNode(1), TreeNode(6)), TreeNode(10))
print(looksValid(broken), isValidBST(broken))
print(looksValid(good), isValidBST(good))
```

```output
true false
true true
```

In `broken`, 9 is the right child of 3, which looks fine locally, but 9 is in the left subtree of 8. `looksValid` never compares 9 with 8, so it says yes.

`isValidBST` fixes that by passing down the **range** each node must fall in:

1. The root can be anything: no lower and no upper bound (`nil`).
2. Going **left** from a node, the upper bound becomes that node's value; the lower bound stays what it was. Going **right**, the lower bound becomes the node's value.
3. When checking 9, the bounds are (3, 8): above 3 because it's in 3's right subtree, below 8 because it's in 8's left subtree. 9 ≥ 8 fails.

Using optionals for the bounds avoids the classic bug of starting with `Int.min` and `Int.max`, which breaks when a node legitimately holds `Int.min`. Each node is checked once: **O(n)** time, O(h) stack.

Another correct approach uses what you already know: a tree is a BST exactly when its inorder traversal is **strictly increasing**. Traverse in order and compare each value with the previous one.

## Balance, and the degenerate case

Every operation above is O(h). How big is h? It depends entirely on the insertion order:

```swift
final class TreeNode {
    var value: Int
    var left: TreeNode?
    var right: TreeNode?
    init(_ value: Int, _ left: TreeNode? = nil, _ right: TreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

func insert(_ node: TreeNode?, _ value: Int) -> TreeNode {
    guard let node else { return TreeNode(value) }
    if value < node.value {
        node.left = insert(node.left, value)
    } else if value > node.value {
        node.right = insert(node.right, value)
    }
    return node
}

func height(_ node: TreeNode?) -> Int {
    guard let node else { return -1 }
    return 1 + max(height(node.left), height(node.right))
}

func build(_ values: [Int]) -> TreeNode? {
    var root: TreeNode? = nil
    for value in values { root = insert(root, value) }
    return root
}

print(height(build([4, 2, 6, 1, 3, 5, 7])))
print(height(build([1, 2, 3, 4, 5, 6, 7])))
print(height(build(Array(1...500))))
```

```output
2
6
499
```

The same seven values give height 2 or height 6. Inserted in sorted order, each value is larger than everything before it, so it goes right every time and the tree becomes a **degenerate** chain: a linked list with extra `nil` pointers. Searching it is O(n), and building it costs 1 + 2 + … + (n − 1) comparisons, **O(n²)**. Sorted input isn't an edge case; it's what you get from a database query, a sorted API response or a timestamped log.

With random insertion order, the expected height is O(log n), but "expected" isn't a guarantee. **Self-balancing BSTs** fix this by restructuring the tree with local **rotations** after inserts and deletes so the height stays O(log n) in the worst case. The best known are **AVL trees** (which keep the heights of every node's two subtrees within 1 of each other) and **red-black trees** (which use node colors to keep the longest path at most twice the shortest). They're the engine behind sorted maps in many languages' libraries. You won't implement one in this course; know they exist, know they make every operation O(log n) worst case, and know what problem they solve.

The Swift standard library has no tree-based sorted collection. In app code the usual choices are:

- a **sorted array** with binary search (Module 16) when reads dominate: O(log n) lookups, O(n) inserts, excellent cache behavior;
- a **Set or Dictionary** when you only need membership, not order;
- **sorting when needed** if the data is small.

A hand-written BST is mostly an interview and teaching tool. The invariant, the bounds trick and the O(h) reasoning carry over to everything else in this module.

## Common mistakes

> [!error] Validating with parent-child comparisons only
> A node can be correct relative to its parent and still violate an ancestor. Pass a lower and an upper bound down the recursion, or check that the inorder sequence is strictly increasing.

> [!error] Starting the bounds at Int.min and Int.max
> If a node holds `Int.min`, the check `value <= lower` rejects a valid tree. Use optional bounds, where `nil` means "no bound".

> [!error] Forgetting to reattach the returned subtree
> With the "return the new subtree root" style, `insert(node.left, value)` alone does nothing visible when `node.left` is `nil`: the new node is created and dropped. Write `node.left = insert(node.left, value)`.

> [!error] Deleting a two-child node by promoting one subtree
> Replacing the node with its left child loses the right subtree, or forces you to graft it somewhere. Copy the successor's value and delete the successor instead.

> [!error] Claiming O(log n) without saying "if balanced"
> A plain BST is O(h). With sorted input h is n − 1. Say O(log n) only for a balanced tree, or say "O(log n) expected for random insertion order".

## Exercises

````exercise
id: m19-l02-e1
type: comprehension
prompt: |
  Which of these trees, written as value(left right) with - for an empty child, is a valid BST?
choices:
  - text: "10(5(2 12) 15)"
    correct: false
    why: 12 is in the left subtree of 10 but larger than 10.
  - text: "10(5(2 7) 15(11 20))"
    correct: true
    why: "Every left subtree is smaller and every right subtree is larger: {5, 2, 7} < 10 < {15, 11, 20}, 2 < 5 < 7, and 11 < 15 < 20."
  - text: "10(5(2 7) 15(9 20))"
    correct: false
    why: 9 is in the right subtree of 10 but smaller than 10.
  - text: "10(5 5)"
    correct: false
    why: "With distinct values, 5 can't be on both sides. Even with duplicates allowed, an equal value has to go to one agreed side."
solution: |
  **10(5(2 7) 15(11 20)).** The others each hide a violation one level below the children: 12 under 5 is fine next to 5 but sits in 10's left subtree; 9 under 15 is fine next to 15 but sits in 10's right subtree. That's exactly the case a parent-child check misses and a bounds check catches: 12 must be in (5, 10), and 9 must be in (10, 15).
````

````exercise
id: m19-l02-e2
type: prediction
prompt: Predict the exact output. The insert ignores duplicates.
code: |
  final class Node {
      var value: Int
      var left: Node?
      var right: Node?
      init(_ value: Int) { self.value = value }
  }

  func insert(_ node: Node?, _ value: Int) -> Node {
      guard let node else { return Node(value) }
      if value < node.value {
          node.left = insert(node.left, value)
      } else if value > node.value {
          node.right = insert(node.right, value)
      }
      return node
  }

  func preorder(_ node: Node?, _ out: inout [Int]) {
      guard let node else { return }
      out.append(node.value)
      preorder(node.left, &out)
      preorder(node.right, &out)
  }

  var root: Node? = nil
  for value in [50, 30, 70, 20, 40, 60, 80, 30, 65] {
      root = insert(root, value)
  }
  var out: [Int] = []
  preorder(root, &out)
  print(out)
  print(root?.right?.left?.right?.value ?? -1)
output: |
  [50, 30, 20, 40, 70, 60, 65, 80]
  65
hints:
  - Draw the tree as you insert. The second 30 is a duplicate.
  - 65 goes right at 50, left at 70, right at 60.
solution: |
  ```output
  [50, 30, 20, 40, 70, 60, 65, 80]
  65
  ```

  50 is the root; 30 and 70 its children; 20 and 40 under 30; 60 and 80 under 70. The second 30 reaches the existing 30 and is ignored. 65 is larger than 50 (right), smaller than 70 (left), larger than 60 (right), so it becomes 60's right child. Preorder visits node, left, right: 50, then 30's subtree (30, 20, 40), then 70's subtree (70, 60, 65, 80). `root?.right?.left?.right` is 70 → 60 → 65.
````

````exercise
id: m19-l02-e3
type: find-errors
prompt: This delete has problems. Which statements are true?
code: |
  func delete(_ node: Node?, _ value: Int) -> Node? {
      guard let node else { return nil }
      if value < node.value {
          delete(node.left, value)
          return node
      }
      if value > node.value {
          node.right = delete(node.right, value)
          return node
      }
      if node.left == nil { return node.right }
      if node.right == nil { return node.left }
      node.value = node.right!.value
      node.right = delete(node.right, node.value)
      return node
  }
choices:
  - text: "Deleting a leaf that is its parent's left child doesn't remove it, because the result of the recursive call on node.left is thrown away."
    correct: true
    why: "The call returns nil for that leaf, but nothing stores it in node.left, so the leaf stays. Swift 6.3 also warns: result of call to 'delete' is unused."
  - text: "For two children it copies the right child's value, which isn't always the smallest value in the right subtree, so the tree can stop being a BST."
    correct: true
    why: "The right child can have a left subtree with smaller values. Those values would end up in the right subtree of a node larger than them."
  - text: The one-child cases are wrong; a node with only a right child can't be replaced by it.
    correct: false
    why: "Replacing a node with its only child keeps the invariant: that subtree was already on the right side of the parent."
  - text: The function should return Node instead of Node?, because a delete never removes the root.
    correct: false
    why: Deleting the only node of a one-node tree must return nil.
rubric:
  - I found the discarded result in the left branch.
  - I found that the two-children case must use the minimum of the right subtree.
  - "I gave a tree where the second bug breaks the invariant, for example deleting 10 from 10(5 20(15 25))."
solution: |
  Two bugs. First, `delete(node.left, value)` ignores its result, so a removed left child is never detached; it must be `node.left = delete(node.left, value)`. Second, the two-children case copies `node.right!.value` instead of the **minimum** of the right subtree.

  Here's a fixed version, run on the tree 10(5 20(15 25)), where copying 20 into the root would put 15 to the right of 20:

  ```swift
  final class Node {
      var value: Int
      var left: Node?
      var right: Node?
      init(_ value: Int, _ left: Node? = nil, _ right: Node? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func delete(_ node: Node?, _ value: Int) -> Node? {
      guard let node else { return nil }
      if value < node.value {
          node.left = delete(node.left, value)
          return node
      }
      if value > node.value {
          node.right = delete(node.right, value)
          return node
      }
      guard let left = node.left else { return node.right }
      guard let right = node.right else { return left }
      var successor = right
      while let smaller = successor.left { successor = smaller }
      node.value = successor.value
      node.right = delete(right, successor.value)
      return node
  }

  func inorder(_ node: Node?) -> [Int] {
      guard let node else { return [] }
      return inorder(node.left) + [node.value] + inorder(node.right)
  }

  var root = delete(Node(10, Node(5), Node(20, Node(15), Node(25))), 10)
  print(root?.value ?? -1, inorder(root))
  root = delete(root, 5)
  print(inorder(root))
  ```

  ```output
  15 [5, 15, 20, 25]
  [15, 20, 25]
  ```

  The successor of 10 is 15, the leftmost node of the right subtree. With the buggy version the root would become 20 and the right subtree would still contain 15, which is smaller than 20. The inorder check (`[5, 15, 20, 25]`, strictly increasing) is a cheap way to test any BST mutation.
````

````exercise
id: m19-l02-e4
type: fill-in
prompt: Complete the bounds check so the program prints `true false false`.
code: |
  final class Node {
      let value: Int
      var left: Node?
      var right: Node?
      init(_ value: Int, _ left: Node? = nil, _ right: Node? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func isValid(_ node: Node?, _ lower: Int?, _ upper: Int?) -> Bool {
      guard let node else { return true }
      if let lower, node.value <= lower { return false }
      if let upper, node.value >= upper { return false }
      return isValid(node.left, [[1]], [[2]])
          && isValid(node.right, [[3]], [[4]])
  }

  let a = Node(20, Node(10, nil, Node(15)), Node(30))
  let b = Node(20, Node(10, nil, Node(25)), Node(30))
  let c = Node(20, Node(10), Node(30, Node(20)))
  print(isValid(a, nil, nil), isValid(b, nil, nil), isValid(c, nil, nil))
blanks:
  - id: "1"
    answers: ["lower"]
  - id: "2"
    answers: ["node.value"]
  - id: "3"
    answers: ["node.value"]
  - id: "4"
    answers: ["upper"]
solution: |
  ```swift
  final class Node {
      let value: Int
      var left: Node?
      var right: Node?
      init(_ value: Int, _ left: Node? = nil, _ right: Node? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func isValid(_ node: Node?, _ lower: Int?, _ upper: Int?) -> Bool {
      guard let node else { return true }
      if let lower, node.value <= lower { return false }
      if let upper, node.value >= upper { return false }
      return isValid(node.left, lower, node.value)
          && isValid(node.right, node.value, upper)
  }

  let a = Node(20, Node(10, nil, Node(15)), Node(30))
  let b = Node(20, Node(10, nil, Node(25)), Node(30))
  let c = Node(20, Node(10), Node(30, Node(20)))
  print(isValid(a, nil, nil), isValid(b, nil, nil), isValid(c, nil, nil))
  ```

  ```output
  true false false
  ```

  Going left narrows the range from above: the new upper bound is the current node. Going right narrows it from below. The inherited bound on the other side is passed through unchanged. In `b`, 25 must be in (10, 20) and isn't. In `c`, the 20 in the right subtree must be in (20, 30), and the strict comparison rejects it as a duplicate.
````

````exercise
id: m19-l02-e5
type: solve
prompt: |
  A leaderboard stores scores in a BST of distinct values. Write `kthSmallest(_ root: Node?, _ k: Int) -> Int?` that returns the k-th smallest score (k = 1 is the minimum), or `nil` if the tree has fewer than k nodes. It must stop as soon as it has the answer: O(h + k) time, not O(n).

  Expected output for the starter's calls:

  ```output
  3 8 14 nil
  ```
starter: |
  final class Node {
      let value: Int
      var left: Node?
      var right: Node?
      init(_ value: Int, _ left: Node? = nil, _ right: Node? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func kthSmallest(_ root: Node?, _ k: Int) -> Int? {
      return nil
  }

  let root = Node(8,
      Node(3, Node(1), Node(6, Node(4), Node(7))),
      Node(10, nil, Node(14, Node(13))))
  let answers = [2, 6, 9, 10].map { kthSmallest(root, $0).map(String.init) ?? "nil" }
  print(answers.joined(separator: " "))
hints:
  - Inorder visits a BST in increasing order.
  - Use the iterative inorder from the previous lesson and count the nodes you pop.
  - Return as soon as the count reaches k.
rubric:
  - Uses inorder order to get values from smallest to largest.
  - Stops after the k-th visit instead of collecting every value.
  - Returns nil when the tree has fewer than k nodes.
  - "States the cost: O(h + k) time, O(h) extra space."
solution: |
  ```swift
  final class Node {
      let value: Int
      var left: Node?
      var right: Node?
      init(_ value: Int, _ left: Node? = nil, _ right: Node? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func kthSmallest(_ root: Node?, _ k: Int) -> Int? {
      var stack: [Node] = []
      var current = root
      var visited = 0
      while current != nil || !stack.isEmpty {
          while let node = current {
              stack.append(node)
              current = node.left
          }
          let node = stack.removeLast()
          visited += 1
          if visited == k { return node.value }
          current = node.right
      }
      return nil
  }

  let root = Node(8,
      Node(3, Node(1), Node(6, Node(4), Node(7))),
      Node(10, nil, Node(14, Node(13))))
  let answers = [2, 6, 9, 10].map { kthSmallest(root, $0).map(String.init) ?? "nil" }
  print(answers.joined(separator: " "))
  ```

  ```output
  3 8 14 nil
  ```

  The iterative inorder pops nodes in increasing order, so the k-th pop is the answer, and returning right there skips the rest of the tree. Before the first pop it walks down the left spine (up to h nodes); after that each pop costs O(1) amortized, so the total is **O(h + k)** time and **O(h)** space for the stack. Collecting the whole inorder into an array and indexing it is correct but O(n). If this query ran constantly on a big tree, you'd store each node's subtree size and find the k-th in O(h) without visiting the smaller nodes at all.
````

````exercise
id: m19-l02-e6
type: explain
prompt: |
  A teammate built a "recent searches" feature that inserts each search timestamp into a hand-written BST and reports that it gets slower as the user searches more. Explain what's happening and what you'd use instead.
code: |
  var recentSearches: TreeNode? = nil

  func recordSearch(at timestamp: Int) {
      recentSearches = insert(recentSearches, timestamp)
  }
rubric:
  - Notices that timestamps arrive in increasing order.
  - Explains that sorted insertion makes the BST a chain of height n − 1, so each insert and search is O(n) and building is O(n²).
  - Names a fix that fits the access pattern (appending to an array, which is already sorted, or a balanced tree if arbitrary inserts are needed).
  - Mentions that balanced BSTs (AVL, red-black) exist to guarantee O(log n) but aren't in the standard library.
solution: |
  Timestamps only grow, so every new one is larger than everything in the tree and goes to the right of the previous one. The BST degenerates into a chain whose height is the number of searches. Each insert walks the whole chain, O(n), so n searches cost O(n²) to record, and lookups are linear too. It's not a bug in the insert; a plain BST has no guarantee about its height.

  Here the data arrives sorted, so a plain `Array` is already the sorted structure: `append` is amortized O(1), the newest items are at the end, and binary search (Module 16) finds a time range in O(log n). If the app ever needed arbitrary inserts in sorted order with fast lookups, the right tool would be a **self-balancing** tree such as an AVL or red-black tree, which keeps the height O(log n) with rotations. The standard library doesn't provide one, which is another reason the array is the pragmatic answer.
````

## Summary

- **BST invariant**: for every node, the whole left subtree is smaller and the whole right subtree is larger. It's about subtrees, not just children.
- **Search** and **insert** follow one path from the root: O(h). Insert puts the value where a failed search ends; the "return the new subtree root" style keeps it short.
- **Delete**: a leaf is removed, a one-child node is replaced by its child, and a two-children node takes its inorder successor's value, after which the successor is deleted from the right subtree.
- **Validate** with a lower and an upper bound passed down (optional, so no sentinel values), or by checking that inorder is strictly increasing. O(n).
- Ordered queries such as minimum, maximum, ceiling and k-th smallest come from the invariant.
- Everything is **O(h)**. Sorted insertion order gives h = n − 1 and O(n) operations. **Self-balancing trees** (AVL, red-black) keep h at O(log n); in Swift apps, a sorted array, a Set or a Dictionary is usually the practical choice.
