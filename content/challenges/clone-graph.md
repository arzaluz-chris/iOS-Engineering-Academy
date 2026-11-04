---
id: clone-graph
title: Clone Graph
difficulty: medium
order: 79
patterns: [Graph, Breadth-first search, Hash map from original to copy]
prerequisites: [m13, m19-l05]
summary: Deep-copy a graph of class instances that point at each other, cycles included. One dictionary serves as both the visited set and the map from each original to its copy.
solutionFile: CloneGraph.swift
testFile: CloneGraphTests.swift
starter: |
  final class CloneGraphNode {
      var value: Int
      var neighbors: [CloneGraphNode]
      init(_ value: Int, neighbors: [CloneGraphNode] = []) {
          self.value = value
          self.neighbors = neighbors
      }
  }

  func cloneGraph(_ node: CloneGraphNode?) -> CloneGraphNode? {
      // Your solution
      return nil
  }
time: O(V + E)
space: O(V)
edgeCases:
  - Empty graph (nil)
  - A single node with no neighbors
  - Two nodes pointing at each other (a cycle)
  - Nodes that aren't reachable from the start (not copied)
askInterviewer:
  - Is the graph connected? Do I copy only what's reachable from the given node?
  - Are values unique, or can two nodes share a value?
  - Does neighbor order matter in the copy?
  - Are the edges undirected (each listed on both ends)?
hints:
  - A plain recursive copy of each neighbor runs forever on the first cycle. What do you need to remember?
  - You need to know, for each original node, whether it has been copied, and if so, which copy it is. One structure can answer both.
  - Class instances aren't Hashable by default. What can you use as a dictionary key that identifies an instance?
followUps:
  - These nodes form reference cycles. What happens to the original graph's memory when the last outside reference goes away, and how would you fix it?
  - Write it with depth-first recursion instead. What's the risk on a long path?
  - Copy a linked list whose nodes also have a random pointer to any node. (Same dictionary idea.)
rubric:
  - I used a dictionary from original node to copy, keyed by ObjectIdentifier.
  - I created each copy once and reused it for every edge that points to it.
  - I handled cycles and the empty graph.
  - I gave O(V + E) time and O(V) space.
codeStatus: tested
---

A note-taking app models linked notes as a graph: each note is a `CloneGraphNode` with a value and an array of the notes it links to. Links go both ways: if A lists B, B lists A. For an "export a copy" feature, the app needs a **deep copy** of everything reachable from one note.

Write `cloneGraph(_:)`, which returns a copy of the graph that contains `node`: new objects with the same values and the same links, in the same neighbor order, sharing no object with the original.

```swift
// A square: 0-1, 1-2, 2-3, 3-0. Each node lists its neighbors in this order:
// 0: [1, 3]   1: [0, 2]   2: [1, 3]   3: [2, 0]
// square is an array holding the four nodes, square[0] through square[3].
let copy = cloneGraph(square[0])
copy?.value                      // 0
copy?.neighbors.map(\.value)     // [1, 3]
copy === square[0]               // false
copy?.neighbors[0] === square[1] // false: the neighbors are copies too

cloneGraph(nil)                  // nil
```

**Constraints:** `0 ≤ V ≤ 100`; the graph is undirected, with no self-loops and no repeated edges.

<!-- reveal -->

## First approach

Copying a node means creating a new node with the same value, then giving it copies of its neighbors. The trap is cycles: copying A copies B, which copies A again, forever. And even without cycles, two nodes that share a neighbor must end up sharing the **same** copy of it. Both problems have the same fix: remember which copy you made for each original, and look it up before making another.

## Naive solution

Collect all reachable originals in an array, make one copy for each position, then wire each edge by finding the neighbor's position in the array:

```swift
func cloneGraph(_ node: CloneGraphNode?) -> CloneGraphNode? {
    guard let node else { return nil }
    var originals = [node]
    var head = 0
    while head < originals.count {
        for neighbor in originals[head].neighbors where !originals.contains(where: { $0 === neighbor }) {
            originals.append(neighbor)
        }
        head += 1
    }
    let copies = originals.map { CloneGraphNode($0.value) }
    for (index, original) in originals.enumerated() {
        for neighbor in original.neighbors {
            let position = originals.firstIndex { $0 === neighbor }!
            copies[index].neighbors.append(copies[position])
        }
    }
    return copies[0]
}
```

It uses `===`, identity, not the values: two different notes can have the same value.

## Problems with the naive solution

`contains(where:)` and `firstIndex(where:)` are linear scans, and they run once per edge: O(V · (V + E)). It's the same mistake as calling `firstIndex(of:)` inside a loop in Two Sum. A dictionary turns each lookup into O(1) on average.

## Optimized solution

A dictionary from each original to its copy. Breadth-first search from the start node: when you see a neighbor that has no copy yet, create its copy and queue the original. Then append the neighbor's copy to the current copy's neighbors. The dictionary is the visited set and the lookup table at the same time.

Class instances aren't `Hashable` unless you make them so, and their values might repeat. `ObjectIdentifier(node)` wraps the instance's identity in a `Hashable` value, which is exactly the key you need.

## Line by line

- `var copies: [ObjectIdentifier: CloneGraphNode] = [ObjectIdentifier(node): CloneGraphNode(node.value)]`: the start node is copied before the loop.
- `var queue = [node]` and `var head = 0`: an array used as a queue with a moving head index, so dequeuing is O(1). `removeFirst()` would be O(n).
- `let copy = copies[ObjectIdentifier(original)]!`: every queued node already has a copy, created when it was first seen.
- `if copies[key] == nil { copies[key] = CloneGraphNode(neighbor.value); queue.append(neighbor) }`: first sighting: create the copy and schedule its own neighbors.
- `copy.neighbors.append(copies[key]!)`: link to the neighbor's copy, never to the original. Neighbor order is preserved because the loop goes through `original.neighbors` in order.
- `return copies[ObjectIdentifier(node)]`: the copy of the start.

## Common mistakes

- Recursing into every neighbor without a map: infinite recursion on the first cycle.
- Creating a new copy for each edge instead of reusing one, so a node with two neighbors gets copied twice.
- Keying the dictionary by `value`, which breaks as soon as two nodes share a value.
- Appending the **original** neighbor to the copy's array, so the copy points back into the original graph.

## Variation

**Copy a linked list with random pointers:** each node has `next` and a `random` pointer to any node or `nil`. Use the same dictionary from original to copy: one pass to create the copies, a second to set `next` and `random` through the dictionary.
