---
id: m19-l01
title: Binary trees and traversals
description: You model a binary tree with a class node and with an indirect enum, visit every node in preorder, inorder and postorder both recursively and with an explicit stack, walk it level by level with a queue, and compute height and depth, with the cost of each traversal in time and space.
module: m19
order: 1
level: intermediate
minutes: 70
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m18-l01, m17-l02]
objectives:
  - Name the parts of a tree (root, child, leaf, subtree, depth, height) and define a binary tree.
  - Model a binary tree node as a class and as an indirect enum, and say when each fits.
  - Write preorder, inorder and postorder traversals recursively and say what each order is good for.
  - Write the same traversals iteratively with an explicit stack.
  - Traverse a tree level by level with a queue.
  - Compute height and depth, and state the time and space cost of every traversal.
terms:
  - term: Tree
    definition: A set of nodes connected by parent-child links, with one node at the top (the root) and no cycles. Every node except the root has exactly one parent.
  - term: Binary tree
    definition: A tree where each node has at most two children, called left and right.
  - term: Leaf
    definition: A node with no children.
  - term: Depth
    definition: The number of edges from the root down to a node. The root has depth 0.
  - term: Height
    definition: The number of edges on the longest path from a node down to a leaf. A leaf has height 0; this lesson gives an empty tree height -1.
  - term: Preorder, inorder, postorder
    definition: The three depth-first orders for a binary tree. They visit the node before its subtrees, between the left and right subtrees, and after both subtrees.
  - term: Level-order traversal
    definition: Visiting nodes by depth, all of depth 0, then all of depth 1, and so on. It's breadth-first search on a tree and uses a queue.
mastery:
  - Write a TreeNode class and build a small tree by hand.
  - Write recursive preorder, inorder and postorder traversals and predict their output for a drawn tree.
  - Write iterative preorder and inorder traversals with an explicit stack.
  - Write a level-order traversal that groups values by level, using a head-index queue.
  - Compute the height of a tree and the depth of every node, using a stated convention.
  - State that each traversal is O(n) time and O(h) extra space (O(w) for level order), and say what h is for a balanced and a degenerate tree.
resources: [swift-book-structures-classes, swift-book-enumerations, swift-book-generics, swift-optional, swift-array]
cards:
  - id: m19-l01-c1
    front: What do preorder, inorder and postorder mean for a binary tree?
    back: "Where the node is visited relative to its subtrees. Preorder: node, left, right. Inorder: left, node, right. Postorder: left, right, node."
  - id: m19-l01-c2
    front: Name a job that needs postorder.
    back: "Anything where a node needs its children's results first: computing folder sizes, the height of a tree, evaluating an expression tree, or freeing a subtree before its parent."
  - id: m19-l01-c3
    front: What extra space does a recursive traversal of a binary tree use?
    back: "O(h), where h is the height, for the call stack. That's O(log n) for a balanced tree and O(n) for a degenerate one that's really a linked list."
  - id: m19-l01-c4
    front: How do you get a level-order traversal grouped by level?
    back: "Use a queue. At the start of each round, read how many nodes are queued: that's exactly one level. Dequeue that many, record their values, and enqueue their children for the next round."
  - id: m19-l01-c5
    front: In an iterative preorder with a stack, why do you push the right child before the left?
    back: "A stack is LIFO. Pushing right first leaves left on top, so the left subtree is processed first, which is what preorder requires."
---

## The idea in one sentence

A tree is a linked structure where each node can point to several children instead of one next node, and every algorithm on it comes down to **choosing the order in which you visit the nodes**.

## Words you need

Draw a tree upside down, root at the top:

```text
          8            depth 0
        /   \
       3     10        depth 1
      / \      \
     1   6      14     depth 2
        / \    /
       4   7  13       depth 3
```

- The **root** is 8. It's the only node without a parent.
- 3 and 10 are the **children** of 8; 8 is their **parent**. Every node except the root has exactly one parent, and there are no cycles. That's what makes it a **tree**.
- A **leaf** has no children: 1, 4, 7 and 13.
- A **subtree** is a node together with everything below it. The subtree rooted at 6 is {6, 4, 7}.
- The **depth** of a node is the number of edges from the root to it. 6 has depth 2.
- The **height** of a node is the number of edges on the longest path from it down to a leaf. A leaf has height 0; 3 has height 2 (3 → 6 → 4); the whole tree has height 3.
- In a **binary tree** each node has at most two children, called **left** and **right**. The distinction matters: a node with only a right child is a different tree from a node with only a left child.

Trees are everywhere in iOS work even when nobody calls them that: the view hierarchy (each view has subviews), the file system, a JSON document, the navigation stack of a split view, and SwiftUI's view graph. Those are general trees, with any number of children. Binary trees are the version algorithms are usually written for, and everything here carries over.

## A node as a class

A node holds a value and two optional children. It has to be a class for the same reason a linked list node does in Module 17: a struct can't contain a property of its own type, but a class stores a reference, which has a fixed size.

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

let root = TreeNode(8,
    TreeNode(3, TreeNode(1), TreeNode(6, TreeNode(4), TreeNode(7))),
    TreeNode(10, nil, TreeNode(14, TreeNode(13))))

print(root.value, root.left?.value ?? -1, root.right?.value ?? -1)
print(root.left?.right?.left?.value ?? -1)
print(root.right?.left == nil)
```

```output
8 3 10
4
true
```

1. `left` and `right` are optional because most nodes are missing at least one child. `nil` is an empty subtree.
2. The initializer takes the children as unlabeled arguments with `nil` defaults, so the construction expression has the same shape as the drawing. Read it from the outside in: 8 has left child 3 (with children 1 and 6) and right child 10 (with only a right child, 14).
3. Optional chaining walks down: `root.left?.right?.left` is 3 → 6 → 4.

The class is `final` because nothing subclasses it, and `var` properties let you rewire the tree, which the next lesson needs for insertion and deletion. Interview problems and most references use exactly this shape, so the rest of the module does too.

## A node as an indirect enum

Module 9 introduced `indirect` for recursive enums. A binary tree is either empty or a node with a value and two subtrees, which is a recursive enum:

```swift
indirect enum BinaryTree<Element> {
    case empty
    case node(BinaryTree, Element, BinaryTree)

    var count: Int {
        switch self {
        case .empty:
            return 0
        case let .node(left, _, right):
            return left.count + 1 + right.count
        }
    }
}

let leaf = { (value: String) in BinaryTree.node(.empty, value, .empty) }
let tree = BinaryTree.node(leaf("a"), "b", .node(.empty, "c", leaf("d")))
print(tree.count)

let bigger = BinaryTree.node(tree, "e", .empty)
print(bigger.count, tree.count)
```

```output
4
5 4
```

`indirect` tells the compiler to store the associated values behind a reference, so the enum has a fixed size even though it contains itself. The enum version is immutable and has value semantics: building `bigger` from `tree` shares `tree`'s nodes internally but nothing can change them, so `tree` is still 4 nodes. That's nice for expression trees, parsed documents and anything you build once and read many times.

The class version is what you want when you **change** the tree in place (insert, delete, rotate) or need node identity. This module uses the class.

## Depth-first traversals

A traversal visits every node exactly once. Recursion fits trees naturally: to process a tree, process the root and process its two subtrees, which are smaller trees. The only question is **when** you visit the root:

| Order | Steps | Our tree |
| --- | --- | --- |
| Preorder | node, left, right | 8 3 1 6 4 7 10 14 13 |
| Inorder | left, node, right | 1 3 4 6 7 8 10 13 14 |
| Postorder | left, right, node | 1 4 7 6 3 13 14 10 8 |

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

func preorder(_ node: TreeNode?, _ result: inout [Int]) {
    guard let node else { return }
    result.append(node.value)
    preorder(node.left, &result)
    preorder(node.right, &result)
}

func inorder(_ node: TreeNode?, _ result: inout [Int]) {
    guard let node else { return }
    inorder(node.left, &result)
    result.append(node.value)
    inorder(node.right, &result)
}

func postorder(_ node: TreeNode?, _ result: inout [Int]) {
    guard let node else { return }
    postorder(node.left, &result)
    postorder(node.right, &result)
    result.append(node.value)
}

let root = TreeNode(8,
    TreeNode(3, TreeNode(1), TreeNode(6, TreeNode(4), TreeNode(7))),
    TreeNode(10, nil, TreeNode(14, TreeNode(13))))

var pre: [Int] = [], inside: [Int] = [], post: [Int] = []
preorder(root, &pre)
inorder(root, &inside)
postorder(root, &post)
print(pre)
print(inside)
print(post)
```

```output
[8, 3, 1, 6, 4, 7, 10, 14, 13]
[1, 3, 4, 6, 7, 8, 10, 13, 14]
[1, 4, 7, 6, 3, 13, 14, 10, 8]
```

1. The base case is the empty subtree: `guard let node else { return }`. Leaves don't need a special case, because their children are `nil` and those calls return at once.
2. The three functions are identical except for the position of `result.append(node.value)`.
3. The result is collected in an `inout` array. Returning `preorder(left) + [value] + preorder(right)` would also work, but it copies arrays at every level, which can cost O(n²) on a deep tree.

To do a traversal by hand, trace the recursion like in Module 18. For inorder: before you can write 8, you must finish the entire left subtree of 8; before you write 3, you finish 3's left subtree, which is just 1. So the output starts 1, 3, and then goes into 6's subtree: 4, 6, 7.

**What each order is for:**

- **Preorder** sees a parent before its children. Use it to copy or serialize a tree (you need to create the parent before attaching children) and to print a hierarchy with indentation, the way Xcode's view debugger lists views.
- **Inorder** only makes sense for binary trees. Notice the output above is sorted. That isn't luck: this tree is a binary search tree, and inorder on a BST gives the values in order. That's the next lesson.
- **Postorder** sees children before their parent. Use it whenever a node's answer depends on its children's answers: the size of a folder, the height of a tree, the value of an expression, or deleting a subtree from the bottom up.

**Cost.** Each node is visited once and does O(1) work, so each traversal is **O(n)** time. The extra space is the call stack: one frame per level of the current path, so **O(h)** where h is the height. For a balanced tree with n nodes, h is about log₂ n; a million nodes need about 20 frames. For a degenerate tree where every node has only a right child, h is n − 1 and the tree is really a linked list. A recursive traversal of a 1,000,000-node chain can overflow the thread's stack and crash. That's one reason to know the iterative versions.

## The same traversals with your own stack

Recursion uses the call stack to remember where to come back to. You can keep that stack yourself in an array (Module 17), which removes the depth limit and makes the order explicit.

**Preorder** is the easy one: pop a node, visit it, push its children. Push the **right child first**, so the left one is on top and comes out next.

**Inorder** has to delay the visit: walk left as far as possible, pushing each node; when you can't go left, pop a node, visit it, and then go to its right subtree.

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

func preorderIterative(_ root: TreeNode?) -> [Int] {
    var result: [Int] = []
    var stack: [TreeNode] = []
    if let root { stack.append(root) }
    while let node = stack.popLast() {
        result.append(node.value)
        if let right = node.right { stack.append(right) }
        if let left = node.left { stack.append(left) }
    }
    return result
}

func inorderIterative(_ root: TreeNode?) -> [Int] {
    var result: [Int] = []
    var stack: [TreeNode] = []
    var current = root
    while current != nil || !stack.isEmpty {
        while let node = current {
            stack.append(node)
            current = node.left
        }
        let node = stack.removeLast()
        result.append(node.value)
        current = node.right
    }
    return result
}

func postorderIterative(_ root: TreeNode?) -> [Int] {
    var result: [Int] = []
    var stack: [TreeNode] = []
    if let root { stack.append(root) }
    while let node = stack.popLast() {
        result.append(node.value)
        if let left = node.left { stack.append(left) }
        if let right = node.right { stack.append(right) }
    }
    return result.reversed()
}

let root = TreeNode(8,
    TreeNode(3, TreeNode(1), TreeNode(6, TreeNode(4), TreeNode(7))),
    TreeNode(10, nil, TreeNode(14, TreeNode(13))))

print(preorderIterative(root))
print(inorderIterative(root))
print(postorderIterative(root))
print(inorderIterative(nil))
```

```output
[8, 3, 1, 6, 4, 7, 10, 14, 13]
[1, 3, 4, 6, 7, 8, 10, 13, 14]
[1, 4, 7, 6, 3, 13, 14, 10, 8]
[]
```

Walkthrough of `inorderIterative`:

1. `current` is the node you're about to explore; `stack` holds nodes whose left subtree you're exploring and which you still have to visit.
2. The inner `while let` slides down the left edge, pushing 8, 3, 1. `current` becomes `nil` below 1.
3. Pop 1, visit it, and move to its right child (`nil`). The inner loop does nothing, so the next pop is 3. Visit 3, move to 6, and the inner loop pushes 6 and 4.
4. The outer condition `current != nil || !stack.isEmpty` covers both "I still have a subtree to explore" and "I still owe some visits".

**Postorder** uses a trick instead of a third algorithm: postorder is left, right, node. Reverse it and you get node, right, left, which is preorder with the children swapped. So run a preorder that pushes left before right, then reverse the result. It needs O(n) space for the result, which you were building anyway. A one-stack postorder that tracks the last visited node also exists; it's fiddlier and rarely worth it.

All three are O(n) time and O(h) extra space for the stack, but now the stack lives on the heap and can grow to millions of entries without crashing.

## Level order with a queue

A **level-order** traversal visits nodes by depth: 8, then 3 and 10, then 1, 6, 14, then 4, 7, 13. You saw this in Module 17: process items with a **queue** and they come out in discovery order, level by level. This is breadth-first search on a tree.

To group values by level, look at the queue at the start of each round: it holds exactly one complete level. Read its size, dequeue that many nodes, and enqueue their children for the next round.

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

func levels(_ root: TreeNode?) -> [[Int]] {
    guard let root else { return [] }
    var result: [[Int]] = []
    var queue = [root]
    var head = 0
    while head < queue.count {
        let levelEnd = queue.count
        var level: [Int] = []
        while head < levelEnd {
            let node = queue[head]
            head += 1
            level.append(node.value)
            if let left = node.left { queue.append(left) }
            if let right = node.right { queue.append(right) }
        }
        result.append(level)
    }
    return result
}

let root = TreeNode(8,
    TreeNode(3, TreeNode(1), TreeNode(6, TreeNode(4), TreeNode(7))),
    TreeNode(10, nil, TreeNode(14, TreeNode(13))))

for (depth, level) in levels(root).enumerated() {
    print(depth, level)
}
```

```output
0 [8]
1 [3, 10]
2 [1, 6, 14]
3 [4, 7, 13]
```

1. The queue is an array with a head index, the Module 17 queue without compaction. Every node is appended once, so the array ends with n elements: O(n) space at worst, which is fine here.
2. `levelEnd` is fixed at the start of the round. Children appended during the round sit past `levelEnd`, so they wait for the next round.
3. Left is enqueued before right, so each level reads left to right.

Time is O(n). The extra space at any moment is the number of queued nodes, which is at most about two levels' worth, O(w) where w is the maximum width. In a complete binary tree the last level holds about n/2 nodes, so level order can use **more** memory than depth-first order (O(log n) there). In a degenerate chain it's the reverse: width 1, height n. Pick by the question you're answering: anything about levels ("the rightmost node on each level", "the minimum depth") is natural with a queue.

> [!warning] Don't use removeFirst() as the dequeue
> `queue.removeFirst()` shifts the whole array, so a level-order traversal built on it is O(n²) on a wide tree. Use a head index, as above, or swap in a fresh array per level.

## Height and depth

Height and depth come from the two directions you can compute things in a tree:

- **Height** flows **up**: a node's height depends on its children's heights. That's postorder.
- **Depth** flows **down**: a node's depth is its parent's depth plus one. That's preorder, passing the depth as a parameter.

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

func height(_ node: TreeNode?) -> Int {
    guard let node else { return -1 }
    return 1 + max(height(node.left), height(node.right))
}

func printDepths(_ node: TreeNode?, depth: Int = 0) {
    guard let node else { return }
    print(String(repeating: "  ", count: depth) + "\(node.value) (depth \(depth))")
    printDepths(node.left, depth: depth + 1)
    printDepths(node.right, depth: depth + 1)
}

let root = TreeNode(8,
    TreeNode(3, TreeNode(1), TreeNode(6, TreeNode(4), TreeNode(7))),
    TreeNode(10, nil, TreeNode(14, TreeNode(13))))

print(height(root), height(root.left), height(TreeNode(5)), height(nil))
printDepths(root)
```

```output
3 2 0 -1
8 (depth 0)
  3 (depth 1)
    1 (depth 2)
    6 (depth 2)
      4 (depth 3)
      7 (depth 3)
  10 (depth 1)
    14 (depth 2)
      13 (depth 3)
```

1. `height` returns -1 for an empty tree, so a leaf gets 1 + max(-1, -1) = 0. The children's heights are computed before the node's, which is postorder.
2. `printDepths` is preorder with an extra parameter. Indenting by depth gives the outline view you know from Xcode's navigators.

> [!note] Two conventions for height
> This lesson counts **edges**: a single node has height 0, an empty tree -1. Many interview problems ask for the "maximum depth" counting **nodes**: a single node has 1, an empty tree 0. They differ by exactly one. Before you answer, check which one the problem means; with nodes, the base case returns 0 instead of -1.

## A practical tree: a folder outline

App data rarely forms a binary tree. A folder has any number of children, so the node holds an array. Here a **struct** works, because an array of nodes stores its elements in separate heap storage and has a fixed size inside the struct:

```swift
struct Item {
    let name: String
    let bytes: Int
    var children: [Item] = []
}

func totalSize(_ item: Item) -> Int {
    var total = item.bytes
    for child in item.children {
        total += totalSize(child)
    }
    return total
}

func outline(_ item: Item, depth: Int = 0) {
    let size = totalSize(item)
    print(String(repeating: "  ", count: depth) + "\(item.name) \(size)")
    for child in item.children {
        outline(child, depth: depth + 1)
    }
}

let documents = Item(name: "Documents", bytes: 0, children: [
    Item(name: "Photos", bytes: 0, children: [
        Item(name: "beach.heic", bytes: 2400),
        Item(name: "cat.heic", bytes: 1800),
    ]),
    Item(name: "notes.txt", bytes: 12),
])
outline(documents)
```

```output
Documents 4212
  Photos 4200
    beach.heic 2400
    cat.heic 1800
  notes.txt 12
```

`totalSize` is postorder (children first, then add the node's own bytes) and `outline` is preorder (print the parent, then the children). But look at the cost: `outline` calls `totalSize` on every node, and `totalSize` walks that node's whole subtree. A node at depth d is counted once for each of its d ancestors plus itself, so this is O(n · h): O(n²) for a deep chain. The fix is to compute all sizes in one postorder pass and store them, then print. Exercise 6 asks you to do that.

## Common mistakes

> [!error] error: recursive enum 'Tree' is not marked 'indirect'
> An enum whose case contains the enum itself needs `indirect`, either on the case or on the whole enum. Swift 6.3 reports this and suggests the fix.

```swift no-compile recursive enum 'Tree' is not marked 'indirect'
enum Tree {
    case empty
    case node(Tree, Int, Tree)
}
print("never runs")
```

> [!error] Pushing the left child first in an iterative preorder
> A stack returns the last thing pushed. If you push left then right, right comes out first, and you get node, right, left: a mirror-image preorder. Push right, then left.

> [!error] Mixing the two height conventions
> Returning 0 for `nil` and also 0 for a leaf can't both be true with `1 + max(...)`. Decide whether you count edges (empty is -1) or nodes (empty is 0), and say which in a comment.

> [!error] Recursing on a tree that might be a chain
> A recursive traversal uses O(h) stack. For trees built from user data (an imported file, a long reply thread) h can be in the hundreds of thousands, and the app crashes with a stack overflow. Use an explicit stack or a queue when the depth isn't bounded.

> [!error] Treating "visited once" as "O(1) work per node"
> A traversal is O(n) only if each visit does O(1) work. Calling an O(subtree) helper at every node, like `totalSize` inside `outline`, quietly makes it O(n · h).

## Exercises

````exercise
id: m19-l01-e1
type: comprehension
prompt: A file-manager feature deletes a folder and everything inside it. The file system refuses to delete a folder that isn't empty. In which order should the code visit the folder tree?
choices:
  - text: Postorder, so every folder's contents are deleted before the folder itself.
    correct: true
    why: Children before parent is exactly the constraint. When a folder is visited, all its children are already gone.
  - text: Preorder, so the top folder is deleted first and the rest goes with it.
    correct: false
    why: The top folder isn't empty yet when preorder reaches it, so the delete fails.
  - text: Level order, so the folders closest to the root are deleted first.
    correct: false
    why: That's also parent before children, the wrong way round for this constraint.
  - text: Any order works, because each item is visited exactly once.
    correct: false
    why: Visiting each node once says nothing about whether a folder is empty when you reach it. The order is the whole point.
solution: |
  **Postorder.** A folder can be deleted only when it's empty, so every child has to be handled before its parent. Postorder visits left subtree, right subtree (for a general tree, all children), then the node, so by the time you reach a folder its contents are already gone. Preorder and level order both reach the parent first, which is the order you'd use to *create* the structure, not to tear it down.
````

````exercise
id: m19-l01-e2
type: prediction
prompt: Predict the exact output. Draw the tree first.
code: |
  final class Node {
      let value: String
      var left: Node?
      var right: Node?
      init(_ value: String, _ left: Node? = nil, _ right: Node? = nil) {
          self.value = value
          self.left = left
          self.right = right
      }
  }

  func walk(_ node: Node?, _ out: inout String) {
      guard let node else { return }
      out += node.value
      walk(node.left, &out)
      walk(node.right, &out)
      out += node.value.lowercased()
  }

  let root = Node("A", Node("B", nil, Node("D")), Node("C"))
  var out = ""
  walk(root, &out)
  print(out)
output: |
  ABDdbCca
hints:
  - "The tree: A has left child B and right child C. B has only a right child, D."
  - Each node writes its uppercase letter when it's entered (preorder) and its lowercase letter when it's left (postorder).
solution: |
  ```output
  ABDdbCca
  ```

  The tree is A with children B and C, and B has a right child D. `walk` appends the uppercase letter before visiting the children and the lowercase one after. Enter A (`A`), enter B (`B`), B has no left child, enter D (`D`), D has no children so leave it (`d`), leave B (`b`), enter C (`C`), leave C (`c`), leave A (`a`). The uppercase letters alone are the preorder ABDC; the lowercase ones alone are the postorder dbca. Every recursive traversal has these two moments, and choosing where you do the work is choosing the order.
````

````exercise
id: m19-l01-e3
type: fill-in
prompt: Complete the iterative inorder traversal so the program prints `[1, 2, 3, 4, 5]`.
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

  func inorder(_ root: Node?) -> [Int] {
      var result: [Int] = []
      var stack: [Node] = []
      var current = root
      while current != nil || !stack.isEmpty {
          while let node = current {
              stack.append(node)
              current = node.[[1]]
          }
          let node = stack.[[2]]()
          result.append(node.value)
          current = node.[[3]]
      }
      return result
  }

  let root = Node(4, Node(2, Node(1), Node(3)), Node(5))
  print(inorder(root))
blanks:
  - id: "1"
    answers: ["left"]
  - id: "2"
    answers: ["removeLast"]
  - id: "3"
    answers: ["right"]
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

  func inorder(_ root: Node?) -> [Int] {
      var result: [Int] = []
      var stack: [Node] = []
      var current = root
      while current != nil || !stack.isEmpty {
          while let node = current {
              stack.append(node)
              current = node.left
          }
          let node = stack.removeLast()
          result.append(node.value)
          current = node.right
      }
      return result
  }

  let root = Node(4, Node(2, Node(1), Node(3)), Node(5))
  print(inorder(root))
  ```

  ```output
  [1, 2, 3, 4, 5]
  ```

  Slide down the left edge pushing every node (4, 2, 1), because none of them can be visited until its left subtree is done. When `current` is `nil`, the top of the stack is the next node in order: pop it, visit it, and continue with its right subtree. `removeLast()` is safe here: the inner loop just pushed at least one node, or the outer condition guarantees the stack isn't empty.
````

````exercise
id: m19-l01-e4
type: solve
prompt: |
  A settings screen shows a tree of options and wants, for each depth, the rightmost option, the one you'd see if you looked at the tree from its right side. Write `rightSideView(_ root: Node?) -> [Int]` that returns the value of the last node on each level, top to bottom. It must be O(n) time.

  Expected output for the starter's calls:

  ```output
  [1, 3, 4]
  [1, 2, 5]
  []
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

  func rightSideView(_ root: Node?) -> [Int] {
      return []
  }

  print(rightSideView(Node(1, Node(2, nil, Node(5)), Node(3, nil, Node(4)))))
  print(rightSideView(Node(1, Node(2, Node(4), Node(5)))))
  print(rightSideView(nil))
hints:
  - Level order gives you each level as a group, left to right.
  - The rightmost node of a level is the last one you dequeue in that round.
  - "The second tree has no right subtree at all: the rightmost node on level 1 is 2, a left child."
rubric:
  - Traverses level by level with a queue and a fixed level size per round.
  - Records the last node of each level, including when it's a left child.
  - Handles the empty tree.
  - Uses a head index (or a fresh array per level) instead of removeFirst(), and states O(n) time and O(w) extra space.
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

  func rightSideView(_ root: Node?) -> [Int] {
      guard let root else { return [] }
      var result: [Int] = []
      var level = [root]
      while !level.isEmpty {
          result.append(level[level.count - 1].value)
          var next: [Node] = []
          for node in level {
              if let left = node.left { next.append(left) }
              if let right = node.right { next.append(right) }
          }
          level = next
      }
      return result
  }

  print(rightSideView(Node(1, Node(2, nil, Node(5)), Node(3, nil, Node(4)))))
  print(rightSideView(Node(1, Node(2, Node(4), Node(5)))))
  print(rightSideView(nil))
  ```

  ```output
  [1, 3, 4]
  [1, 2, 5]
  []
  ```

  This version keeps one array per level instead of a single queue with a head index. It's the same breadth-first order: `level` holds exactly one depth, left to right, and `next` collects the following depth. The last element of each level is what you see from the right. Following only right children would be wrong: in the second tree, 2 is a left child and still the rightmost node at depth 1. Each node is appended once and read once, so it's **O(n) time**, with **O(w)** extra space for the two level arrays. A depth-first alternative also works: traverse node, right, left, and record a node's value the first time you reach a new depth.
````

````exercise
id: m19-l01-e5
type: find-errors
prompt: This function is meant to return the minimum depth of a tree, counting nodes, the number of nodes on the shortest path from the root to a leaf. For the tree 1 → (left 2, right nil), the answer is 2. Which statements are true?
code: |
  func minDepth(_ node: Node?) -> Int {
      guard let node else { return 0 }
      return 1 + min(minDepth(node.left), minDepth(node.right))
  }
choices:
  - text: It returns 1 for the tree 1 → (left 2, right nil), because the missing right child counts as a path of length 0.
    correct: true
    why: "minDepth(nil) is 0, so min(1, 0) is 0 and the result is 1. But the root isn't a leaf; a nil child isn't a path to a leaf."
  - text: It's correct for trees where every node has either zero or two children.
    correct: true
    why: The bug only shows when a node has exactly one child. With zero or two children, every nil it sees belongs to a real leaf.
  - text: It crashes on an empty tree.
    correct: false
    why: The guard returns 0 for nil.
  - text: It's O(n²) because it recurses twice per node.
    correct: false
    why: Two recursive calls per node still visit each node once. It's O(n).
rubric:
  - I found that a nil child is treated as a leaf.
  - I fixed it by ignoring the missing side when a node has only one child.
  - I noticed that level order can stop at the first leaf it meets, which can be faster.
solution: |
  The bug is treating an empty subtree as a path to a leaf. A path has to end at a real leaf, a node with **no** children. If one side is missing, the minimum must come from the other side:

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

  func minDepth(_ node: Node?) -> Int {
      guard let node else { return 0 }
      switch (node.left, node.right) {
      case (nil, nil):
          return 1
      case (let left?, nil):
          return 1 + minDepth(left)
      case (nil, let right?):
          return 1 + minDepth(right)
      case (let left?, let right?):
          return 1 + min(minDepth(left), minDepth(right))
      }
  }

  print(minDepth(Node(1, Node(2))))
  print(minDepth(Node(1, Node(2, Node(4)), Node(3))))
  print(minDepth(nil))
  ```

  ```output
  2
  2
  0
  ```

  The `switch` on the pair of children names all four cases, so the one-child cases can't be forgotten. This is O(n). A level-order version can do better on wide trees: return the depth of the **first** leaf it dequeues, without looking at the deeper levels at all.
````

````exercise
id: m19-l01-e6
type: refactor
prompt: |
  The folder outline from the lesson calls `totalSize` at every node, which makes it O(n · h). Rewrite it so the whole outline is O(n): compute every folder's size in one pass, then print. Keep the same output.
code: |
  struct Item {
      let name: String
      let bytes: Int
      var children: [Item] = []
  }

  func totalSize(_ item: Item) -> Int {
      var total = item.bytes
      for child in item.children {
          total += totalSize(child)
      }
      return total
  }

  func outline(_ item: Item, depth: Int = 0) {
      print(String(repeating: "  ", count: depth) + "\(item.name) \(totalSize(item))")
      for child in item.children {
          outline(child, depth: depth + 1)
      }
  }
rubric:
  - Computes each subtree's size exactly once.
  - Prints parents before children with the right indentation and sizes.
  - "Explains why the original is O(n · h) and the new one is O(n)."
solution: |
  The parent's line has to be printed before its children's, but its size is only known after them. So collect the lines in postorder and insert the parent's line in front of its children's lines, or, simpler, have one recursive function return the size and append its line into a buffer at a reserved position:

  ```swift
  struct Item {
      let name: String
      let bytes: Int
      var children: [Item] = []
  }

  func outline(_ item: Item, depth: Int, into lines: inout [String]) -> Int {
      let index = lines.count
      lines.append("")
      var total = item.bytes
      for child in item.children {
          total += outline(child, depth: depth + 1, into: &lines)
      }
      lines[index] = String(repeating: "  ", count: depth) + "\(item.name) \(total)"
      return total
  }

  let documents = Item(name: "Documents", bytes: 0, children: [
      Item(name: "Photos", bytes: 0, children: [
          Item(name: "beach.heic", bytes: 2400),
          Item(name: "cat.heic", bytes: 1800),
      ]),
      Item(name: "notes.txt", bytes: 12),
  ])
  var lines: [String] = []
  _ = outline(documents, depth: 0, into: &lines)
  for line in lines {
      print(line)
  }
  ```

  ```output
  Documents 4212
    Photos 4200
      beach.heic 2400
      cat.heic 1800
    notes.txt 12
  ```

  The function reserves the node's line on the way down (preorder position), fills it in on the way up once the children's totals are known (postorder value), and returns its total to the parent. Every node is visited once and does O(1) work besides its children, so it's **O(n)** time and O(n) space for the lines, plus O(h) stack. The original was O(n · h) because each node's bytes were summed again for every one of its ancestors.
````

## Summary

- A **tree** has one root, one parent per other node and no cycles. In a **binary tree** each node has at most a left and a right child.
- Model nodes with a **final class** when you change the tree in place; an **indirect enum** gives an immutable tree with value semantics.
- **Preorder** (node, left, right) for copying and printing hierarchies, **inorder** (left, node, right) for sorted order in a BST, **postorder** (left, right, node) when a node needs its children's answers.
- Recursive traversals are O(n) time and O(h) stack. For a chain, h is n and deep recursion can crash; an explicit stack avoids that. Iterative preorder pushes right before left; iterative postorder is a reversed node-right-left preorder.
- **Level order** uses a queue; reading the queue's size at the start of each round gives one level. O(n) time, O(w) space.
- **Height** flows up (postorder), **depth** flows down (preorder with a parameter). Say whether you count edges or nodes.
