---
id: m19-l07
title: Union-find
description: You track groups that merge over time with a parent array, see how a naive union-find degenerates into O(n) chains, fix it with union by size and path compression, count connected components and detect cycles in undirected graphs as edges arrive, merge duplicate contacts that share a phone number, and learn the inverse-Ackermann bound as a known result.
module: m19
order: 7
level: advanced
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m19-l05]
objectives:
  - Explain the disjoint-set problem and when union-find fits better than BFS or DFS.
  - Implement find and union on a parent array, where each set is a tree identified by its root.
  - Add union by size (or rank) and prove that it keeps trees at height O(log n).
  - Add path compression and state the combined amortized bound, the inverse Ackermann function, as a known result.
  - Use union-find to count connected components and to detect cycles in an undirected graph.
terms:
  - term: Disjoint sets
    definition: A collection of sets where no element belongs to two sets. Union-find maintains such a partition as sets merge.
  - term: Union-find
    definition: A data structure with two operations, find (which set is x in?) and union (merge the sets of x and y). Also called disjoint-set union (DSU).
  - term: Representative
    definition: One element chosen to identify a set. In union-find it's the root of the set's tree, and find returns it.
  - term: Union by size
    definition: When merging two trees, attaching the root of the smaller one under the root of the larger one. Union by rank does the same with an upper bound on height instead of size.
  - term: Path compression
    definition: During find, making the nodes on the path point directly (or closer) to the root, so later finds on them are shorter.
  - term: Inverse Ackermann function
    definition: "α(n), a function that grows so slowly that it's at most 4 for any input size that fits in the physical universe. Union-find with both optimizations costs O(α(n)) amortized per operation."
mastery:
  - Implement a UnionFind struct with a parent array, find, union and a component count.
  - Show how unions without balancing can build a chain, and why union by size bounds the height by log₂ n.
  - Implement path compression iteratively, without recursion.
  - Detect the edge that closes a cycle in an undirected graph.
  - Group items that share any attribute (such as a phone number) by mapping attributes to elements and unioning.
  - Choose between union-find and BFS/DFS from how the edges arrive and what's asked.
resources: [swift-array, swift-dictionary, swift-book-structures-classes, swift-book-methods]
cards:
  - id: m19-l07-c1
    front: How does a parent array represent disjoint sets?
    back: "Each set is a tree. parent[x] is x's parent, and a root points to itself. find(x) follows parents to the root, which identifies the set. Two elements are in the same set exactly when they have the same root."
  - id: m19-l07-c2
    front: Why does union by size keep union-find trees short?
    back: "A node gets one level deeper only when its tree is attached under a tree at least as big, so the size of the tree containing it at least doubles. That can happen at most log₂ n times."
  - id: m19-l07-c3
    front: What does path compression do?
    back: "During find, it makes the nodes on the path point directly (or, with path halving, closer) to the root. Later finds on those nodes take one or two steps."
  - id: m19-l07-c4
    front: What's the cost of union-find with union by size and path compression?
    back: "O(α(n)) amortized per operation, where α is the inverse Ackermann function, at most 4 for any practical n. It's a known result (Tarjan, 1975); for practical purposes it's constant."
  - id: m19-l07-c5
    front: How do you detect a cycle in an undirected graph with union-find?
    back: "Process the edges one at a time. If an edge's two endpoints already have the same root, they were already connected, so this edge closes a cycle. Otherwise, union them."
---

## The idea in one sentence

Union-find keeps track of which items are in the same group while groups keep merging, and answers "are these two together?" in practically constant time, by storing each group as a tree that only ever needs to point toward its root.

## The problem: groups that merge

Some questions about connectivity arrive one fact at a time:

- A contacts importer learns that card 3 and card 8 share a phone number, then that card 8 and card 12 share an email. Which cards are the same person?
- A network tool adds cables between devices one by one and must answer "can A reach B?" after each.
- A photo app links two photos whenever face detection says they show the same person.

You could rebuild an adjacency list and run BFS after every new fact, but that's O(V + E) per query. **Union-find** (also called **disjoint-set union**) supports exactly two operations, both nearly O(1):

- `find(x)`: which group is x in? It returns the group's **representative**, one element that names the group.
- `union(x, y)`: merge the group of x with the group of y.

Two elements are in the same group exactly when `find` returns the same representative for both. What union-find **can't** do: split a group, remove a connection, or tell you the path between two elements. It only knows membership.

## A forest in an array

Number the elements 0 to n − 1. Each group is a **tree**, stored as one array: `parent[x]` is x's parent, and a root is its own parent. `find` follows parents up to the root; `union` finds both roots and makes one the parent of the other.

```swift
struct NaiveUnionFind {
    var parent: [Int]

    init(_ count: Int) {
        parent = Array(0..<count)
    }

    func find(_ x: Int) -> Int {
        var node = x
        while parent[node] != node {
            node = parent[node]
        }
        return node
    }

    mutating func union(_ a: Int, _ b: Int) {
        let rootA = find(a), rootB = find(b)
        if rootA != rootB {
            parent[rootA] = rootB
        }
    }
}

var groups = NaiveUnionFind(6)
groups.union(0, 1)
groups.union(2, 3)
groups.union(1, 3)
print(groups.parent)
print(groups.find(0) == groups.find(2), groups.find(4) == groups.find(5))

var chain = NaiveUnionFind(6)
for x in 1..<6 {
    chain.union(x - 1, x)
}
print(chain.parent)
```

```output
[1, 3, 3, 3, 4, 5]
true false
[1, 2, 3, 4, 5, 5]
```

1. Initially every element is its own group: `parent[x] == x`.
2. `union(0, 1)` makes 1 the parent of 0. `union(2, 3)` makes 3 the parent of 2. `union(1, 3)` finds roots 1 and 3 and makes 3 the parent of 1. Now 0 → 1 → 3 ← 2: one group, root 3.
3. `union` always links **roots**, never the elements themselves. Linking `parent[a] = b` directly would cut a off from its own old root's group.

The second example shows the problem. Unioning 0-1, 1-2, 2-3 and so on, always putting the old root under the new element's root, builds a **chain**: `find(0)` walks 5 steps. With n elements a find costs O(n), the same degenerate case as a BST built from sorted input.

## Fix 1: union by size

When merging two trees, attach the **smaller** tree's root under the **larger** tree's root. Track each root's size in a second array.

**Why it keeps trees short.** A node's depth increases by one only when its tree is attached under another root, and with union by size that happens only when the other tree is at least as big. So every time the node gets deeper, the size of the tree containing it at least **doubles**. A tree can't have more than n nodes, so that can happen at most log₂ n times: every tree has height at most **log₂ n**, and `find` is O(log n).

**Union by rank** is a common variant: instead of sizes, each root stores an upper bound on its tree's height (its rank), and the lower-rank root goes under the higher-rank one. Same O(log n) guarantee. Size has the bonus that it tells you how big each group is.

## Fix 2: path compression

Every find walks a path to the root. Since you've just learned the root of every node on that path, make them point **directly** at it. The next find on any of them takes one step. The simplest correct version does two passes: one to find the root, one to repoint the path.

```swift
struct UnionFind {
    private var parent: [Int]
    private var size: [Int]
    private(set) var componentCount: Int

    init(_ count: Int) {
        parent = Array(0..<count)
        size = Array(repeating: 1, count: count)
        componentCount = count
    }

    mutating func find(_ x: Int) -> Int {
        var root = x
        while parent[root] != root {
            root = parent[root]
        }
        var node = x
        while parent[node] != root {
            let next = parent[node]
            parent[node] = root
            node = next
        }
        return root
    }

    @discardableResult
    mutating func union(_ a: Int, _ b: Int) -> Bool {
        var rootA = find(a), rootB = find(b)
        if rootA == rootB { return false }
        if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
        parent[rootB] = rootA
        size[rootA] += size[rootB]
        componentCount -= 1
        return true
    }

    mutating func connected(_ a: Int, _ b: Int) -> Bool {
        find(a) == find(b)
    }

    mutating func groupSize(_ x: Int) -> Int {
        size[find(x)]
    }
}

var devices = UnionFind(8)
devices.union(0, 1)
devices.union(2, 3)
devices.union(1, 3)
devices.union(5, 6)
print(devices.componentCount, devices.groupSize(2), devices.groupSize(4))
print(devices.connected(0, 2), devices.connected(0, 5))
print(devices.union(3, 0), devices.componentCount)
```

```output
4 4 1
true false
false 4
```

1. `size[r]` is only meaningful for roots. When `rootB` goes under `rootA`, its size is added to `rootA`'s.
2. `swap(&rootA, &rootB)` makes sure `rootA` is the bigger one, so the attach line is the same in both cases.
3. `union` returns whether it actually merged. `@discardableResult` lets callers ignore that, while code that needs it (cycle detection, below) can read it.
4. `componentCount` starts at n and drops by one on every successful union, so it's always the number of groups. Here: {0, 1, 2, 3}, {4}, {5, 6}, {7}.
5. `union(3, 0)` returns `false`: they were already in the same group.
6. `find` is `mutating` because path compression rewrites `parent`. That's why `connected` and `groupSize` are `mutating` too, even though they look like queries.

> [!note] Path halving
> A popular one-pass alternative, **path halving**, makes each node on the path point to its grandparent as you climb: `parent[node] = parent[parent[node]]; node = parent[node]`. It doesn't flatten the path completely in one find, but it gets the same asymptotic bound and needs only one loop. The recursive one-liner `parent[x] = find(parent[x])` is also common; it recurses as deep as the path, which is fine with union by size (at most log₂ n) but not on a naive chain.

## How fast is it?

With union by size alone, every operation is O(log n). With path compression alone, the amortized cost is also O(log n). With **both**, the amortized cost per operation is **O(α(n))**, where α is the **inverse Ackermann function**. This is a known result, proved by Robert Tarjan in 1975; the proof is well beyond this course. What you need to know about α is how slowly it grows: α(n) ≤ 4 for every n you could ever store, since it only reaches 5 at a number far larger than the count of atoms in the observable universe. In practice, union-find operations are constant time.

"Amortized" matters, as in Module 15: a single find right after many unions can still walk a path of several steps; it's the total over a sequence of m operations that is O(m α(n)).

## Components and cycles as edges arrive

**Counting components** is the `componentCount` above: start at n, subtract one per successful union. Unlike BFS, it stays up to date after each new edge without re-traversing anything.

**Detecting a cycle in an undirected graph**: process the edges one at a time. If an edge's endpoints are **already connected**, then there was already a path between them, and this edge closes a cycle. Otherwise, union them.

```swift
struct UnionFind {
    private var parent: [Int]
    private var size: [Int]
    init(_ count: Int) {
        parent = Array(0..<count)
        size = Array(repeating: 1, count: count)
    }
    mutating func find(_ x: Int) -> Int {
        var node = x
        while parent[node] != node {
            parent[node] = parent[parent[node]]
            node = parent[node]
        }
        return node
    }
    mutating func union(_ a: Int, _ b: Int) -> Bool {
        var rootA = find(a), rootB = find(b)
        if rootA == rootB { return false }
        if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
        parent[rootB] = rootA
        size[rootA] += size[rootB]
        return true
    }
}

func firstCycleEdge(_ count: Int, _ edges: [(Int, Int)]) -> (Int, Int)? {
    var sets = UnionFind(count)
    for edge in edges {
        if !sets.union(edge.0, edge.1) {
            return edge
        }
    }
    return nil
}

let cables = [(0, 1), (1, 2), (3, 4), (2, 0), (2, 3)]
if let edge = firstCycleEdge(5, cables) {
    print("cycle closed by", edge.0, "-", edge.1)
}
print(firstCycleEdge(4, [(0, 1), (1, 2), (2, 3)]) == nil)
```

```output
cycle closed by 2 - 0
true
```

This `find` uses **path halving**: one loop, each step pointing a node at its grandparent. Cable 2-0 is the first whose endpoints were already connected (through 0-1 and 1-2), so it's the one that closes a cycle. Each edge costs one union: O(E α(V)) in total.

This only works for **undirected** graphs. For directed graphs, connectivity isn't symmetric, and cycle detection needs the three-state DFS or Kahn's algorithm from the previous lesson. Union-find is also the core of **Kruskal's algorithm** for minimum spanning trees: sort the edges by weight and keep each edge that joins two different components.

## A practical example: merging duplicate contacts

An importer has contact cards, each with some phone numbers. Two cards that share any number belong to the same person, and that relation is transitive: if A shares a number with B, and B with C, all three are one person even if A and C share nothing. Union-find handles the transitivity for you:

```swift
struct UnionFind {
    private var parent: [Int]
    private var size: [Int]
    init(_ count: Int) {
        parent = Array(0..<count)
        size = Array(repeating: 1, count: count)
    }
    mutating func find(_ x: Int) -> Int {
        var node = x
        while parent[node] != node {
            parent[node] = parent[parent[node]]
            node = parent[node]
        }
        return node
    }
    mutating func union(_ a: Int, _ b: Int) {
        var rootA = find(a), rootB = find(b)
        if rootA == rootB { return }
        if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
        parent[rootB] = rootA
        size[rootA] += size[rootB]
    }
}

struct Card {
    let name: String
    let phones: [String]
}

func mergeDuplicates(_ cards: [Card]) -> [[String]] {
    var sets = UnionFind(cards.count)
    var ownerOfPhone: [String: Int] = [:]
    for (index, card) in cards.enumerated() {
        for phone in card.phones {
            if let owner = ownerOfPhone[phone] {
                sets.union(owner, index)
            } else {
                ownerOfPhone[phone] = index
            }
        }
    }

    var groups: [Int: [String]] = [:]
    for index in cards.indices {
        groups[sets.find(index), default: []].append(cards[index].name)
    }
    return groups.values.map { $0.sorted() }.sorted { $0[0] < $1[0] }
}

let cards = [
    Card(name: "Ana (work)", phones: ["555-0101", "555-0199"]),
    Card(name: "Ben", phones: ["555-0300"]),
    Card(name: "Ana M.", phones: ["555-0199"]),
    Card(name: "A. Martin", phones: ["555-0777", "555-0101"]),
    Card(name: "Benjamin", phones: ["555-0300", "555-0301"]),
    Card(name: "Cy", phones: []),
]
for group in mergeDuplicates(cards) {
    print(group)
}
```

```output
["A. Martin", "Ana (work)", "Ana M."]
["Ben", "Benjamin"]
["Cy"]
```

1. `ownerOfPhone` remembers the first card that had each number. Every later card with the same number is unioned with that first card. There's no need to compare all pairs of cards, which would be O(n²).
2. "Ana M." and "A. Martin" share no number, but both share one with "Ana (work)", so they end up in the same set.
3. Grouping by `find(index)` collects each set's names. Sorting the names, then the groups, makes the output deterministic regardless of dictionary order.
4. With P phone numbers in total, this is O(P) dictionary operations plus O(P α(n)) for the union-find: effectively linear.

## Union-find or BFS/DFS?

| Situation | Better tool |
| --- | --- |
| The whole graph is known, one question about it | BFS or DFS, O(V + E) |
| Edges arrive over time, with connectivity queries in between | Union-find |
| You need the path, or distances | BFS (DFS for any path) |
| Edges get removed, groups split | Neither directly: recompute, or use more advanced structures |
| Directed graph | BFS or DFS; union-find is for undirected connectivity |

## Common mistakes

> [!error] Linking elements instead of roots
> `parent[a] = b` detaches a from its tree's root and leaves the rest of a's old group behind. Always find both roots and link one root under the other.

> [!error] Comparing parents instead of roots
> `parent[a] == parent[b]` is not "same set": two elements can be in the same tree at different depths. Compare `find(a) == find(b)`.

> [!error] Updating size on the wrong root
> After `parent[rootB] = rootA`, it's `size[rootA]` that grows. Sizes of non-roots are stale and never read.

> [!error] Decrementing the component count on every union call
> A union of two elements already in the same set changes nothing. Decrement only when the roots were different.

> [!error] Recursive find on an unbalanced structure
> Without union by size, a chain can be n long, and a recursive find can overflow the stack. Use union by size, or an iterative find.

## Exercises

````exercise
id: m19-l07-e1
type: comprehension
prompt: A chat app wants to support "remove friend" and to keep answering "are A and B in the same friend group (directly or through friends)?" after each change. Is union-find a good fit?
choices:
  - text: No. Union-find can merge groups but can't split them when an edge is removed.
    correct: true
    why: A removed friendship may or may not split a group, and union-find has no operation to undo a union.
  - text: Yes. Removing a friend is a union in reverse.
    correct: false
    why: There's no reverse union. The parent array doesn't record which edges caused which links.
  - text: Yes, as long as it uses path compression.
    correct: false
    why: Path compression makes finds fast but makes undoing even harder, since it rewrites the tree structure.
  - text: No, because union-find only works for directed graphs.
    correct: false
    why: It's the other way around. Union-find models undirected connectivity.
solution: |
  **No.** Union-find supports adding connections, not removing them. After a removal, the group may stay connected through other friendships or split in two, and the parent array doesn't remember which edges exist, so it can't tell. Options are recomputing components with BFS or DFS after removals, or processing the changes offline in reverse (removals become additions), which is an advanced technique. If friendships are only ever added, union-find is ideal.
````

````exercise
id: m19-l07-e2
type: prediction
prompt: Predict the exact output. This union-find uses union by size (ties attach b's root under a's root) and no path compression.
code: |
  var parent = Array(0..<6)
  var size = Array(repeating: 1, count: 6)

  func find(_ x: Int, _ parent: [Int]) -> Int {
      var node = x
      while parent[node] != node { node = parent[node] }
      return node
  }

  func union(_ a: Int, _ b: Int, _ parent: inout [Int], _ size: inout [Int]) {
      var rootA = find(a, parent), rootB = find(b, parent)
      if rootA == rootB { return }
      if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
      parent[rootB] = rootA
      size[rootA] += size[rootB]
  }

  union(0, 1, &parent, &size)
  union(2, 3, &parent, &size)
  union(4, 2, &parent, &size)
  union(1, 3, &parent, &size)
  union(5, 0, &parent, &size)
  print(parent)
  print(find(1, parent), size[find(5, parent)])
output: |
  [2, 0, 2, 2, 2, 2]
  2 6
hints:
  - "union(0, 1): equal sizes, so 1 goes under 0. union(2, 3): 3 goes under 2."
  - "union(4, 2): 4's root is 4 (size 1), 2's root is 2 (size 2). The smaller one, 4, goes under 2."
  - "union(1, 3): roots 0 (size 2) and 2 (size 3). 0 goes under 2."
solution: |
  ```output
  [2, 0, 2, 2, 2, 2]
  2 6
  ```

  Step by step: `union(0, 1)` → parent[1] = 0, size[0] = 2. `union(2, 3)` → parent[3] = 2, size[2] = 2. `union(4, 2)`: root 4 has size 1 and root 2 has size 2, so after the swap 4 goes under 2, size[2] = 3. `union(1, 3)`: find(1) is 0 (size 2), find(3) is 2 (size 3), so 0 goes under 2, size[2] = 5. `union(5, 0)`: find(5) is 5 (size 1), find(0) is 2 (size 5), so 5 goes under 2, size[2] = 6. Element 1 still points to 0, because there's no path compression; its root is 2, two steps up. The tallest path has length 2, well within log₂ 6.
````

````exercise
id: m19-l07-e3
type: fill-in
prompt: Complete `find` with path halving and `union` by size so the program prints `3 true false`.
code: |
  struct Sets {
      var parent: [Int]
      var size: [Int]
      var count: Int

      init(_ n: Int) {
          parent = Array(0..<n)
          size = Array(repeating: 1, count: n)
          count = n
      }

      mutating func find(_ x: Int) -> Int {
          var node = x
          while parent[node] != node {
              parent[node] = parent[[[1]]]
              node = parent[node]
          }
          return node
      }

      mutating func union(_ a: Int, _ b: Int) {
          var rootA = find(a), rootB = find(b)
          if rootA == rootB { return }
          if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
          parent[[[2]]] = rootA
          size[rootA] += size[[[3]]]
          count -= 1
      }
  }

  var sets = Sets(6)
  sets.union(0, 1)
  sets.union(1, 2)
  sets.union(3, 4)
  sets.union(2, 0)
  print(sets.count, sets.find(2) == sets.find(0), sets.find(4) == sets.find(5))
blanks:
  - id: "1"
    answers: ["parent[node]"]
  - id: "2"
    answers: ["rootB"]
  - id: "3"
    answers: ["rootB"]
solution: |
  ```swift
  struct Sets {
      var parent: [Int]
      var size: [Int]
      var count: Int

      init(_ n: Int) {
          parent = Array(0..<n)
          size = Array(repeating: 1, count: n)
          count = n
      }

      mutating func find(_ x: Int) -> Int {
          var node = x
          while parent[node] != node {
              parent[node] = parent[parent[node]]
              node = parent[node]
          }
          return node
      }

      mutating func union(_ a: Int, _ b: Int) {
          var rootA = find(a), rootB = find(b)
          if rootA == rootB { return }
          if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
          parent[rootB] = rootA
          size[rootA] += size[rootB]
          count -= 1
      }
  }

  var sets = Sets(6)
  sets.union(0, 1)
  sets.union(1, 2)
  sets.union(3, 4)
  sets.union(2, 0)
  print(sets.count, sets.find(2) == sets.find(0), sets.find(4) == sets.find(5))
  ```

  ```output
  3 true false
  ```

  Path halving points each node at its **grandparent**, `parent[parent[node]]`, then moves up to it. Union attaches the smaller root, `rootB` after the swap, under the larger and adds its size to the larger root. The count starts at 6 and drops on the three real merges; `union(2, 0)` finds the same root and returns early. The groups are {0, 1, 2}, {3, 4} and {5}.
````

````exercise
id: m19-l07-e4
type: find-errors
prompt: This union-find has bugs. Which statements are true?
code: |
  struct Sets {
      var parent: [Int]
      var count: Int

      init(_ n: Int) {
          parent = Array(0..<n)
          count = n
      }

      func find(_ x: Int) -> Int {
          var node = x
          while parent[node] != node { node = parent[node] }
          return node
      }

      mutating func union(_ a: Int, _ b: Int) {
          parent[a] = b
          count -= 1
      }

      func connected(_ a: Int, _ b: Int) -> Bool {
          parent[a] == parent[b]
      }
  }
choices:
  - text: "union links a itself instead of a's root, so other members of a's old group can be left behind."
    correct: true
    why: "After union(0, 1), union(0, 2) sets parent[0] = 2, and 1 (which 0 used to point to) is no longer connected to 0 or 2."
  - text: The count drops even when a and b are already in the same group.
    correct: true
    why: There's no check that the roots differ.
  - text: "connected compares parents, which fails for elements at different depths of the same tree."
    correct: true
    why: Two elements in the same set can have different parents. Compare find(a) and find(b).
  - text: find is wrong because it isn't mutating.
    correct: false
    why: Without path compression find doesn't change anything, so it doesn't need to be mutating. It's slow on chains, but correct.
rubric:
  - I found that union must link roots, not elements.
  - I found the unconditional count decrement.
  - I found the parent comparison in connected.
  - I added union by size and path compression or explained why they're needed for performance.
solution: |
  Three correctness bugs. Here's a fixed version with a test that would have failed on each of them:

  ```swift
  struct Sets {
      var parent: [Int]
      var size: [Int]
      var count: Int

      init(_ n: Int) {
          parent = Array(0..<n)
          size = Array(repeating: 1, count: n)
          count = n
      }

      mutating func find(_ x: Int) -> Int {
          var node = x
          while parent[node] != node {
              parent[node] = parent[parent[node]]
              node = parent[node]
          }
          return node
      }

      mutating func union(_ a: Int, _ b: Int) {
          var rootA = find(a), rootB = find(b)
          if rootA == rootB { return }
          if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
          parent[rootB] = rootA
          size[rootA] += size[rootB]
          count -= 1
      }

      mutating func connected(_ a: Int, _ b: Int) -> Bool {
          find(a) == find(b)
      }
  }

  var sets = Sets(4)
  sets.union(0, 1)
  sets.union(0, 2)
  sets.union(1, 2)
  print(sets.count, sets.connected(1, 2), sets.connected(0, 3))
  ```

  ```output
  2 true false
  ```

  With the original code, `union(0, 2)` would set `parent[0] = 2` and strand 1; `union(1, 2)` would decrement the count again even though it should be a no-op; and `connected` would compare direct parents. The fixed version links roots, decrements only on a real merge, and compares roots. Union by size and path halving aren't needed for correctness, but without them a long chain makes every find O(n).
````

````exercise
id: m19-l07-e5
type: solve
prompt: |
  A network of n devices (0 to n − 1) is connected by cables, given in the order they were installed. Write `redundantCables(_ n: Int, _ cables: [(Int, Int)]) -> [(Int, Int)]` that returns every cable that connected two devices that could already reach each other when it was installed, in installation order, or an empty array if there are none. Use union-find so the whole thing is close to O(n + number of cables).

  Expected output for the starter's calls:

  ```output
  [(1, 2)]
  [(3, 1), (4, 2)]
  []
  ```
starter: |
  func redundantCables(_ n: Int, _ cables: [(Int, Int)]) -> [(Int, Int)] {
      return []
  }

  print(redundantCables(3, [(0, 1), (0, 2), (1, 2)]))
  print(redundantCables(5, [(0, 1), (1, 2), (2, 3), (3, 1), (0, 4), (4, 2)]))
  print(redundantCables(4, [(0, 1), (2, 3)]))
hints:
  - A cable is redundant exactly when its two endpoints are already in the same set.
  - Make union return whether it merged anything.
  - Process the cables in order, and don't union a redundant cable's endpoints (they're already together anyway).
rubric:
  - Implements find with path compression (or halving) and union by size or rank.
  - Detects redundant cables by finding that both endpoints have the same root before the union.
  - Returns them in installation order.
  - "States the cost: O(n + E α(n))."
solution: |
  ```swift
  struct UnionFind {
      private var parent: [Int]
      private var size: [Int]

      init(_ count: Int) {
          parent = Array(0..<count)
          size = Array(repeating: 1, count: count)
      }

      mutating func find(_ x: Int) -> Int {
          var node = x
          while parent[node] != node {
              parent[node] = parent[parent[node]]
              node = parent[node]
          }
          return node
      }

      mutating func union(_ a: Int, _ b: Int) -> Bool {
          var rootA = find(a), rootB = find(b)
          if rootA == rootB { return false }
          if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
          parent[rootB] = rootA
          size[rootA] += size[rootB]
          return true
      }
  }

  func redundantCables(_ n: Int, _ cables: [(Int, Int)]) -> [(Int, Int)] {
      var network = UnionFind(n)
      var redundant: [(Int, Int)] = []
      for cable in cables where !network.union(cable.0, cable.1) {
          redundant.append(cable)
      }
      return redundant
  }

  print(redundantCables(3, [(0, 1), (0, 2), (1, 2)]))
  print(redundantCables(5, [(0, 1), (1, 2), (2, 3), (3, 1), (0, 4), (4, 2)]))
  print(redundantCables(4, [(0, 1), (2, 3)]))
  ```

  ```output
  [(1, 2)]
  [(3, 1), (4, 2)]
  []
  ```

  Each cable either merges two different groups (it's needed) or finds its endpoints already together (it's redundant, and it closes a cycle). The `where` clause calls `union` once per cable and keeps the ones where it returned `false`. In the second network, 3-1 closes the cycle 1-2-3, and 4-2 closes 0-4-2-1-0. Creating the structure is O(n) and each cable costs O(α(n)) amortized, so the total is **O(n + E α(n))**, effectively linear. A BFS from scratch after each cable would be O(E · (n + E)).
````

````exercise
id: m19-l07-e6
type: explain
prompt: |
  Explain why union by size guarantees that every tree has height at most log₂ n, and why that alone already makes find O(log n). Then say, in a sentence or two, what path compression adds and how the combined bound is usually stated.
code: |
  mutating func union(_ a: Int, _ b: Int) {
      var rootA = find(a), rootB = find(b)
      if rootA == rootB { return }
      if size[rootA] < size[rootB] { swap(&rootA, &rootB) }
      parent[rootB] = rootA
      size[rootA] += size[rootB]
  }
rubric:
  - Notes that a node's depth increases only when its root is attached under another root.
  - Explains that with union by size this happens only when the other tree is at least as big, so the size of the node's tree at least doubles.
  - Concludes that it can happen at most log₂ n times, so the height is at most log₂ n.
  - Connects height to the cost of find.
  - Says that path compression flattens paths during finds, and that with both the amortized cost is O(α(n)), the inverse Ackermann function, stated as a known result.
solution: |
  Follow a single element x. Its depth (distance to its root) only changes when its tree's root is attached under another root during a union; then every node in x's tree, including x, gets one level deeper. With union by size, x's tree is attached only under a tree that is **at least as large**, so the new combined tree is at least twice the size of x's old tree. Starting from size 1, the size of x's tree can double at most log₂ n times before it exceeds n. So x's depth is at most log₂ n, for every x, and every tree has height at most log₂ n. `find` walks from x to its root, one step per level, so it's O(log n), and `union` is two finds plus O(1).

  Path compression makes every node on a find's path point straight to the root (or, with halving, to its grandparent), so repeated finds get cheaper over time. With both optimizations, a sequence of m operations on n elements costs O(m α(n)), where α is the inverse Ackermann function. That bound is Tarjan's result, which we use without proof; α(n) is at most 4 for any realistic n, so in practice each operation is constant time.
````

## Summary

- **Union-find** maintains disjoint groups under merging, with `find` (which group?) and `union` (merge two groups). It can't split groups or report paths.
- Each group is a tree in a **parent array**; the root is the **representative**. Always link **roots**, and compare `find` results, not parents.
- **Union by size** (or rank) attaches the smaller tree under the larger, which bounds the height by **log₂ n**, because a node gets deeper only when its tree doubles.
- **Path compression** (or path halving) repoints nodes toward the root during `find`. With both, the amortized cost is **O(α(n))**, the inverse Ackermann function, a known result (Tarjan, 1975) that is at most 4 in practice.
- **Components**: start the count at n and decrement on each real merge. **Cycles in undirected graphs**: an edge whose endpoints already share a root closes a cycle.
- Prefer union-find when edges arrive over time with queries in between; prefer BFS/DFS for a static graph, for paths and distances, and for directed graphs.
