---
id: m19-l05
title: Graphs, BFS and DFS
description: You model graphs with adjacency lists and adjacency matrices, directed and undirected, traverse them breadth-first with a queue and depth-first with recursion or a stack using a visited set, find shortest paths in unweighted graphs and rebuild the path itself, count connected components, and treat a 2D grid as a graph without building one.
module: m19
order: 5
level: intermediate
minutes: 75
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m19-l01, m18-l02]
objectives:
  - Define graphs, directed and undirected edges, neighbors, paths, cycles and connected components.
  - Represent a graph as an adjacency list and as an adjacency matrix, and compare their costs.
  - Write BFS and DFS with a visited set, and explain why a graph traversal needs one when a tree traversal doesn't.
  - Find the shortest path in an unweighted graph with BFS, and rebuild the path from parent links.
  - Count and label connected components.
  - Traverse a grid as an implicit graph with direction offsets and bounds checks.
terms:
  - term: Graph
    definition: A set of vertices (nodes) and a set of edges, each connecting two vertices. Unlike a tree, a graph has no root and can contain cycles.
  - term: Directed and undirected
    definition: In a directed graph each edge goes one way, from u to v. In an undirected graph an edge connects u and v both ways.
  - term: Adjacency list
    definition: A representation where each vertex stores the list of its neighbors. Uses O(V + E) space.
  - term: Adjacency matrix
    definition: A V × V table where entry [u][v] says whether there's an edge from u to v. Uses O(V²) space and answers "is there an edge?" in O(1).
  - term: Breadth-first search (BFS)
    definition: A traversal that visits vertices in order of their distance from the start, using a queue. In an unweighted graph it finds shortest paths.
  - term: Depth-first search (DFS)
    definition: A traversal that follows one path as far as it can before backtracking, using recursion or a stack.
  - term: Connected component
    definition: In an undirected graph, a maximal set of vertices where every vertex can reach every other.
mastery:
  - Build an adjacency list from an edge list, for directed and undirected graphs.
  - Choose between an adjacency list and a matrix from the graph's size and the queries needed.
  - Write BFS that marks vertices visited when they're enqueued, and returns distances.
  - Rebuild a shortest path from BFS parent links.
  - Write recursive and iterative DFS, and count connected components.
  - Run BFS or DFS on a grid with four direction offsets.
  - State that BFS and DFS are O(V + E) with an adjacency list.
resources: [swift-dictionary, swift-set, swift-array, swift-optional]
cards:
  - id: m19-l05-c1
    front: Why does a graph traversal need a visited set when a tree traversal doesn't?
    back: "A graph can have cycles and several paths to the same vertex. Without remembering what you've seen, BFS or DFS would visit vertices again and could loop forever."
  - id: m19-l05-c2
    front: In BFS, when should you mark a vertex as visited?
    back: "When you enqueue it, not when you dequeue it. Otherwise the same vertex can be enqueued many times by different neighbors before it's processed."
  - id: m19-l05-c3
    front: Why does BFS find shortest paths in an unweighted graph?
    back: "It processes vertices in order of distance: all vertices at distance d leave the queue before any at distance d + 1 enter it. The first time a vertex is discovered is through a shortest path."
  - id: m19-l05-c4
    front: Adjacency list or matrix for a social network with 1 million users and about 200 friends each?
    back: "List. The matrix would have 10¹² entries, almost all empty. The list stores about 2 × 10⁸ entries, O(V + E), and iterates a user's friends in O(degree)."
  - id: m19-l05-c5
    front: What's the cost of BFS or DFS on an adjacency list?
    back: "O(V + E) time: each vertex is processed once and each edge is examined once (twice for undirected). O(V) extra space for the visited set and the queue or stack."
---

## The idea in one sentence

A graph is a tree without the rules: no root, any vertex can connect to any other, and cycles are allowed, so **every traversal has to remember where it has been**.

## What a graph is

A **graph** is a set of **vertices** (nodes) and a set of **edges** between them. Social networks (users and friendships), maps (intersections and roads), app navigation (screens and links, which you saw in Module 17), module dependencies in Xcode, and a level in a game are all graphs.

- In an **undirected** graph, an edge connects two vertices both ways: friendship. In a **directed** graph, an edge goes from u to v: "follows", "links to", "depends on".
- The **neighbors** of v are the vertices it has an edge to. Their number is its **degree**.
- A **path** is a sequence of vertices joined by edges. A **cycle** is a path that returns to its start.
- Edges can carry **weights** (a distance, a cost). This lesson's graphs are unweighted: every edge counts as one step.

A tree is a special graph: connected, undirected, no cycles. The new difficulty with general graphs is that you can reach the same vertex along different paths, or come back to it around a cycle.

## Representing a graph

Number the vertices 0 to V − 1 (map names to numbers with a dictionary if needed). Two common representations:

**Adjacency list**: for each vertex, the array of its neighbors. **Adjacency matrix**: a V × V grid of booleans, where `matrix[u][v]` is `true` if there's an edge from u to v.

```swift
let vertexCount = 5
let edges = [(0, 1), (0, 2), (1, 3), (2, 3), (3, 4)]

var adjacency = Array(repeating: [Int](), count: vertexCount)
var matrix = Array(repeating: Array(repeating: false, count: vertexCount), count: vertexCount)
for (u, v) in edges {
    adjacency[u].append(v)
    adjacency[v].append(u)
    matrix[u][v] = true
    matrix[v][u] = true
}

for (vertex, neighbors) in adjacency.enumerated() {
    print(vertex, neighbors)
}
print(matrix[1][3], matrix[1][2])
print(matrix[3].map { $0 ? "1" : "0" }.joined())
```

```output
0 [1, 2]
1 [0, 3]
2 [0, 3]
3 [1, 2, 4]
4 [3]
true false
01101
```

1. The graph is undirected, so each edge is stored twice: v in u's list and u in v's list. For a directed graph you'd store only `adjacency[u].append(v)`.
2. The matrix row for 3 has a 1 in columns 1, 2 and 4.

How they compare, with V vertices and E edges:

| | Adjacency list | Adjacency matrix |
| --- | --- | --- |
| Space | O(V + E) | O(V²) |
| Is there an edge u → v? | O(degree of u) | O(1) |
| Iterate the neighbors of u | O(degree of u) | O(V) |
| A full BFS or DFS | O(V + E) | O(V²) |

Most real graphs are **sparse**: far fewer edges than the V² possible. A million users with 200 friends each is 10⁸ friendships; a matrix would need 10¹² cells. Use an adjacency list by default, and a matrix only for small, dense graphs or when constant-time edge checks dominate. When vertices are strings, a `[String: [String]]` dictionary is an adjacency list too, as in Module 17.

## Breadth-first search

BFS is the level-order traversal from the first lesson, applied to a graph, plus a **visited set**. From the start vertex, visit everything at distance 1, then everything at distance 2, and so on. The queue keeps that order: every vertex at distance d is enqueued before any vertex at distance d + 1.

```swift
func bfs(from start: Int, in adjacency: [[Int]]) -> [Int?] {
    var distance = [Int?](repeating: nil, count: adjacency.count)
    distance[start] = 0
    var queue = [start]
    var head = 0
    while head < queue.count {
        let vertex = queue[head]
        head += 1
        for neighbor in adjacency[vertex] where distance[neighbor] == nil {
            distance[neighbor] = distance[vertex]! + 1
            queue.append(neighbor)
        }
    }
    print("visit order:", queue)
    return distance
}

let adjacency = [[1, 2], [0, 3], [0, 3], [1, 2, 4], [3], [6], [5]]
let distance = bfs(from: 0, in: adjacency)
print(distance.map { $0.map(String.init) ?? "-" }.joined(separator: " "))
```

```output
visit order: [0, 1, 2, 3, 4]
0 1 1 2 3 - -
```

1. `distance` doubles as the visited set: `nil` means "not discovered yet". A separate `Set<Int>` or `[Bool]` works too.
2. A vertex gets its distance and is marked **when it's enqueued**. If you waited until it's dequeued, vertex 3 would be enqueued twice, once by 1 and once by 2, before either copy was processed.
3. Vertices 5 and 6 are connected only to each other, so BFS from 0 never reaches them: their distance stays `nil`.
4. The queue is the head-index array from Module 17. Because nothing is ever removed, `queue` ends up holding the visit order.

**Why the distances are shortest.** When a vertex is first discovered, it's discovered from a vertex at the smallest distance that has an edge to it, because vertices leave the queue in non-decreasing order of distance. Any other path to it would go through vertices that leave the queue later, so it can't be shorter. This only holds when every edge costs the same; weighted graphs need Dijkstra's algorithm, which replaces the queue with the priority queue from the previous lesson.

**Cost.** Each vertex is enqueued and dequeued at most once: O(V). Each vertex's adjacency list is scanned once when it's dequeued, so all scans together look at every edge once (twice for undirected): O(E). Total **O(V + E)** time, O(V) extra space.

## Getting the path, not just the distance

To return the route itself, record for each vertex the vertex it was discovered **from**, its **parent** in the BFS tree. Then walk back from the target to the start and reverse.

```swift
func shortestPath(from start: String, to target: String, in graph: [String: [String]]) -> [String]? {
    var parent: [String: String] = [:]
    var visited: Set<String> = [start]
    var queue = [start]
    var head = 0
    while head < queue.count {
        let vertex = queue[head]
        head += 1
        if vertex == target { break }
        for neighbor in graph[vertex, default: []] where !visited.contains(neighbor) {
            visited.insert(neighbor)
            parent[neighbor] = vertex
            queue.append(neighbor)
        }
    }
    guard visited.contains(target) else { return nil }
    var path = [target]
    while let previous = parent[path[path.count - 1]] {
        path.append(previous)
    }
    return path.reversed()
}

let follows: [String: [String]] = [
    "ana": ["ben", "cy"],
    "ben": ["dee"],
    "cy": ["dee", "eli"],
    "dee": ["fay"],
    "eli": ["fay"],
    "fay": ["ana"],
]
print(shortestPath(from: "ana", to: "fay", in: follows) ?? [])
print(shortestPath(from: "eli", to: "ben", in: follows) ?? [])
print(shortestPath(from: "dee", to: "dee", in: follows) ?? [])
print(shortestPath(from: "ben", to: "zed", in: follows) ?? ["no path"])
```

```output
["ana", "ben", "dee", "fay"]
["eli", "fay", "ana", "ben"]
["dee"]
["no path"]
```

1. This graph is **directed**: "ana follows ben" doesn't mean ben follows ana. The adjacency list only has the forward edges, and BFS follows them.
2. `parent` stores the BFS tree. The start has no parent, which is what ends the walk back.
3. The `break` stops as soon as the target is dequeued. Everything needed is already in `parent`.
4. There are three shortest paths from ana to fay: through ben and dee, through cy and dee, and through cy and eli. BFS returns one of them, and which one depends on the order of the neighbor lists.

## Depth-first search

DFS goes as deep as it can along one path, and backtracks when it runs out of unvisited neighbors. It's the recursive tree traversal from the first lesson plus a visited set, and the same shape as backtracking in Module 18, except that a visited vertex stays visited: you never un-choose it.

```swift
func dfsRecursive(_ vertex: Int, _ adjacency: [[Int]], _ visited: inout [Bool], _ order: inout [Int]) {
    visited[vertex] = true
    order.append(vertex)
    for neighbor in adjacency[vertex] where !visited[neighbor] {
        dfsRecursive(neighbor, adjacency, &visited, &order)
    }
}

func dfsIterative(from start: Int, _ adjacency: [[Int]]) -> [Int] {
    var visited = Array(repeating: false, count: adjacency.count)
    var order: [Int] = []
    var stack = [start]
    while let vertex = stack.popLast() {
        if visited[vertex] { continue }
        visited[vertex] = true
        order.append(vertex)
        for neighbor in adjacency[vertex].reversed() where !visited[neighbor] {
            stack.append(neighbor)
        }
    }
    return order
}

let adjacency = [[1, 2], [0, 3], [0, 3], [1, 2, 4], [3]]
var visited = Array(repeating: false, count: adjacency.count)
var order: [Int] = []
dfsRecursive(0, adjacency, &visited, &order)
print(order)
print(dfsIterative(from: 0, adjacency))
```

```output
[0, 1, 3, 2, 4]
[0, 1, 3, 2, 4]
```

1. The `where !visited[neighbor]` filter is checked as the loop reaches each neighbor, so a vertex visited deeper in the recursion is skipped when control comes back.
2. From 0, DFS goes to 1, then 3, then 2 (3's first unvisited neighbor), finds 2's neighbors all visited, backtracks to 3, and goes to 4. BFS visited 0, 1, 2, 3, 4: by distance.
3. The iterative version marks vertices when they're **popped**, unlike BFS. A vertex can be pushed several times, and the `continue` skips stale copies. That's what makes it visit in true DFS order; marking on push would be valid as a traversal but gives a different order. The stack can hold O(E) entries.
4. Pushing neighbors in **reverse** makes the first neighbor come out first, matching the recursive order.

DFS is also O(V + E). It doesn't find shortest paths: it found 2 through 1 and 3, a path of length 3, though 2 is a neighbor of 0. Its strengths are elsewhere: exploring everything reachable, detecting cycles, and the ordering in the next lesson. Like any recursion, a deep graph (a chain of 100,000 vertices) can overflow the call stack; the iterative version doesn't.

## Connected components

In an undirected graph, a **connected component** is a group of vertices that can all reach each other. To find them all, loop over every vertex and start a traversal from each one that isn't visited yet. Each start discovers exactly one new component.

```swift
func components(_ vertexCount: Int, _ edges: [(Int, Int)]) -> [Int] {
    var adjacency = Array(repeating: [Int](), count: vertexCount)
    for (u, v) in edges {
        adjacency[u].append(v)
        adjacency[v].append(u)
    }
    var label = Array(repeating: -1, count: vertexCount)
    var current = 0
    for start in 0..<vertexCount where label[start] == -1 {
        label[start] = current
        var stack = [start]
        while let vertex = stack.popLast() {
            for neighbor in adjacency[vertex] where label[neighbor] == -1 {
                label[neighbor] = current
                stack.append(neighbor)
            }
        }
        current += 1
    }
    return label
}

let labels = components(8, [(0, 1), (1, 2), (3, 4), (5, 6), (6, 7), (7, 5)])
print(labels)
print("components:", (labels.max() ?? -1) + 1)
```

```output
[0, 0, 0, 1, 1, 2, 2, 2]
components: 3
```

The label array is the visited set and the answer at once. Here the traversal marks on push, since only reachability matters, not the order. Every vertex and edge is handled once across **all** the traversals together, so the whole thing is still O(V + E), not O(V · (V + E)). Uses: "how many separate friend groups", "which photos belong to the same cluster", "can these two devices reach each other at all".

Union-find, two lessons from now, answers the same question when edges arrive one at a time.

## Grids are graphs

Many problems hand you a 2D grid: a map, a game board, an image. Each cell is a vertex, and its neighbors are the cells up, down, left and right (sometimes diagonals too). You don't build an adjacency list; you compute neighbors on the fly with **direction offsets** and a bounds check.

Here's the shortest number of moves through a maze from S to E, with `#` as walls:

```swift
func shortestMoves(_ rows: [String]) -> Int? {
    let grid = rows.map { Array($0) }
    let height = grid.count
    let width = grid[0].count
    var start = (0, 0), end = (0, 0)
    for r in 0..<height {
        for c in 0..<width {
            if grid[r][c] == "S" { start = (r, c) }
            if grid[r][c] == "E" { end = (r, c) }
        }
    }

    let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    var distance = Array(repeating: Array(repeating: -1, count: width), count: height)
    distance[start.0][start.1] = 0
    var queue = [start]
    var head = 0
    while head < queue.count {
        let (r, c) = queue[head]
        head += 1
        if (r, c) == end { return distance[r][c] }
        for (dr, dc) in directions {
            let nr = r + dr, nc = c + dc
            guard nr >= 0, nr < height, nc >= 0, nc < width else { continue }
            guard grid[nr][nc] != "#", distance[nr][nc] == -1 else { continue }
            distance[nr][nc] = distance[r][c] + 1
            queue.append((nr, nc))
        }
    }
    return nil
}

let maze = [
    "S.#.....",
    ".##.###.",
    "....#...",
    "#.#...#E",
]
print(shortestMoves(maze) ?? -1)
print(shortestMoves(["S#E"]) ?? -1)
```

```output
12
-1
```

1. `Array($0)` turns each row string into an array of `Character`s so cells can be indexed by integer.
2. `directions` lists the four moves. Adding an offset gives a neighbor's coordinates; the first `guard` throws away anything off the grid, the second walls and visited cells.
3. The 2D `distance` array is the visited set, with -1 for "not reached".
4. Tuples of `Int` can be compared with `==`, which is how the loop checks whether it reached the end.

The grid has V = rows × columns vertices and at most 4V edges, so BFS is O(rows × columns). The same loop with a stack instead of a queue, or recursion, is how you **flood fill** a region, the "paint bucket" in a drawing app, or count islands of land in a map.

## Common mistakes

> [!error] No visited set
> On a graph with a cycle, BFS or DFS without one runs forever (or until memory runs out). Even without cycles, a vertex reachable by several paths gets processed several times.

> [!error] Marking visited on dequeue in BFS
> The same vertex can be enqueued once per neighbor before it's processed, and its distance might be set more than once. Mark it when you enqueue it.

> [!error] Storing an undirected edge in one direction only
> If friendship (u, v) is only in u's list, a traversal from v never finds u. Append both directions for undirected graphs.

> [!error] Using DFS for "fewest steps"
> DFS finds *a* path, not the shortest. For shortest paths in unweighted graphs, use BFS.

> [!error] Checking bounds after indexing
> `grid[nr][nc]` with nr = -1 crashes before any check runs. Do the bounds check first, in its own `guard`.

> [!error] Forgetting disconnected parts
> A single traversal from vertex 0 only covers 0's component. To process the whole graph, loop over all vertices and start from each unvisited one.

## Exercises

````exercise
id: m19-l05-e1
type: comprehension
prompt: A messaging app models 2 million users and their blocked-user relations (on average 3 per user) and needs, for each incoming message, to check whether the recipient blocked the sender. Which representation fits?
choices:
  - text: An adjacency list, or a Set of blocked IDs per user, because the graph is very sparse.
    correct: true
    why: "There are about 6 million edges. A list or set per user stores O(V + E) and a per-user Set answers the membership check in O(1) average."
  - text: An adjacency matrix, because it answers "is there an edge?" in O(1).
    correct: false
    why: "It would need 4 × 10¹² cells, almost all false. The O(1) check isn't worth that memory, and a Set per user gives O(1) on average anyway."
  - text: An adjacency matrix, because messages are frequent.
    correct: false
    why: "Frequency of queries doesn't change the space cost, and the space cost here is impossible."
  - text: "A single array of all (blocker, blocked) pairs, scanned for each message."
    correct: false
    why: That's O(E) per message, about 6 million comparisons.
solution: |
  **An adjacency list, ideally with a `Set` per user.** The graph is sparse: 2 million vertices but only about 6 million edges, while a matrix has 4 trillion cells. A `[UserID: Set<UserID>]` is an adjacency list whose neighbor collections are sets, so "did the recipient block the sender?" is one dictionary lookup and one set lookup, O(1) on average, in O(V + E) space. The matrix's one advantage, constant-time edge checks, is matched here without its memory cost.
````

````exercise
id: m19-l05-e2
type: prediction
prompt: Predict the exact output. The graph is undirected and the neighbor lists are in the order shown.
code: |
  let adjacency = [[1, 4], [0, 2, 3], [1, 5], [1, 5], [0], [2, 3]]

  var visited = Set([0])
  var queue = [0]
  var head = 0
  while head < queue.count {
      let vertex = queue[head]
      head += 1
      for neighbor in adjacency[vertex] where !visited.contains(neighbor) {
          visited.insert(neighbor)
          queue.append(neighbor)
      }
  }
  print(queue)

  func dfs(_ vertex: Int, _ seen: inout Set<Int>, _ order: inout [Int]) {
      seen.insert(vertex)
      order.append(vertex)
      for neighbor in adjacency[vertex] where !seen.contains(neighbor) {
          dfs(neighbor, &seen, &order)
      }
  }
  var seen = Set<Int>()
  var order: [Int] = []
  dfs(0, &seen, &order)
  print(order)
output: |
  [0, 1, 4, 2, 3, 5]
  [0, 1, 2, 5, 3, 4]
hints:
  - "BFS: 0's neighbors are 1 and 4. Then 1 adds 2 and 3. 4 adds nothing new. 2 adds 5."
  - "DFS goes deep first: 0 → 1 → 2 → 5, and from 5 its neighbor 3 is still unvisited."
solution: |
  ```output
  [0, 1, 4, 2, 3, 5]
  [0, 1, 2, 5, 3, 4]
  ```

  BFS processes by distance: 0 (distance 0), then 1 and 4 (distance 1), then 2 and 3 (discovered from 1, distance 2), then 5 (discovered from 2, distance 3). When 3 is processed, 5 is already marked, so it isn't added again.

  DFS from 0 goes to its first neighbor 1, then 1's first unvisited neighbor 2, then 2's unvisited neighbor 5, then 5's unvisited neighbor 3. From 3, every neighbor is seen, so it backtracks all the way to 0, whose second neighbor 4 is still unvisited. DFS reached 3 through a path of length 4 (0, 1, 2, 5, 3) even though 3 is two steps from 0.
````

````exercise
id: m19-l05-e3
type: find-errors
prompt: This BFS is meant to return the number of edges on the shortest path from start to target in an undirected graph, or -1 if there's none. Which statements are true?
code: |
  func distance(from start: Int, to target: Int, _ adjacency: [[Int]]) -> Int {
      var visited = Set<Int>()
      var queue = [(start, 0)]
      while !queue.isEmpty {
          let (vertex, steps) = queue.removeFirst()
          if vertex == target { return steps }
          visited.insert(vertex)
          for neighbor in adjacency[vertex] where !visited.contains(neighbor) {
              queue.append((neighbor, steps + 1))
          }
      }
      return -1
  }
choices:
  - text: A vertex can be enqueued several times, because it's only marked visited when it's dequeued.
    correct: true
    why: "Two vertices at the same distance that share a neighbor both enqueue it before it's processed. On dense graphs the queue can grow far beyond V."
  - text: removeFirst() makes each dequeue O(n), so the BFS can be quadratic in the queue length.
    correct: true
    why: removeFirst shifts every remaining element. Use a head index.
  - text: It can return a distance that's longer than the shortest one.
    correct: false
    why: Duplicates are wasteful, but the first time the target is dequeued is still at its smallest distance, because the queue stays in non-decreasing distance order.
  - text: It loops forever on a graph with a cycle.
    correct: false
    why: Once a copy of a vertex is dequeued, the vertex is marked and no new copies of it are made, so the queue eventually empties. It can hold a lot of duplicates first.
rubric:
  - I found the late marking and explained the duplicate enqueues.
  - I found the O(n) removeFirst.
  - I explained why the answer is still correct, just slower.
  - "I fixed both: mark on enqueue, and use a head index."
solution: |
  The function returns the right answers but does too much work. Marking on dequeue lets a vertex be enqueued once per neighbor that discovers it, and `removeFirst()` turns each dequeue into an O(n) shift. Fixed:

  ```swift
  func distance(from start: Int, to target: Int, _ adjacency: [[Int]]) -> Int {
      var visited: Set<Int> = [start]
      var queue = [(start, 0)]
      var head = 0
      while head < queue.count {
          let (vertex, steps) = queue[head]
          head += 1
          if vertex == target { return steps }
          for neighbor in adjacency[vertex] where !visited.contains(neighbor) {
              visited.insert(neighbor)
              queue.append((neighbor, steps + 1))
          }
      }
      return -1
  }

  let square = [[1, 2], [0, 3], [0, 3], [1, 2]]
  print(distance(from: 0, to: 3, square), distance(from: 2, to: 2, square))
  print(distance(from: 0, to: 1, [[], []]))
  ```

  ```output
  2 0
  -1
  ```

  In the square 0-1-3-2-0, the original would enqueue 3 twice (from 1 and from 2). The fixed one marks 3 when 1 discovers it, so 2 skips it. Each vertex now enters the queue once: O(V + E).
````

````exercise
id: m19-l05-e4
type: fill-in
prompt: Complete the grid traversal so it counts the cells reachable from the top-left corner, moving up, down, left and right through `.` cells. The program should print `9`.
code: |
  let grid = [
      Array("..#."),
      Array(".##."),
      "....".map { $0 },
      Array("####"),
  ]
  let height = grid.count, width = grid[0].count
  var seen = Array(repeating: Array(repeating: false, count: width), count: height)
  var stack = [(0, 0)]
  seen[0][0] = true
  var count = 0
  while let (r, c) = stack.popLast() {
      count += 1
      for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
          let nr = r + dr, nc = c + dc
          guard nr >= 0, nr < [[1]], nc >= 0, nc < [[2]] else { continue }
          guard grid[nr][nc] == ".", ![[3]][nr][nc] else { continue }
          seen[nr][nc] = true
          stack.append((nr, nc))
      }
  }
  print(count)
blanks:
  - id: "1"
    answers: ["height"]
  - id: "2"
    answers: ["width"]
  - id: "3"
    answers: ["seen"]
solution: |
  ```swift
  let grid = [
      Array("..#."),
      Array(".##."),
      "....".map { $0 },
      Array("####"),
  ]
  let height = grid.count, width = grid[0].count
  var seen = Array(repeating: Array(repeating: false, count: width), count: height)
  var stack = [(0, 0)]
  seen[0][0] = true
  var count = 0
  while let (r, c) = stack.popLast() {
      count += 1
      for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
          let nr = r + dr, nc = c + dc
          guard nr >= 0, nr < height, nc >= 0, nc < width else { continue }
          guard grid[nr][nc] == ".", !seen[nr][nc] else { continue }
          seen[nr][nc] = true
          stack.append((nr, nc))
      }
  }
  print(count)
  ```

  ```output
  9
  ```

  Rows are bounded by `height` and columns by `width`, and the bounds check comes before any indexing. `seen` marks cells when they're pushed, so each cell is counted once. From (0, 0) the walk reaches (0, 1) and (1, 0), goes down to the third row and along all four of its cells, then up the right column through (1, 3) to (0, 3). That's 2 + 1 + 4 + 2 = 9 cells. The bottom row is all wall, and the walls at (0, 2), (1, 1) and (1, 2) are never counted. The rows are built two ways, `Array("..#.")` and `"....".map { $0 }`; both give `[Character]`.
````

````exercise
id: m19-l05-e5
type: solve
prompt: |
  A team-building app splits people into two teams so that every pair of rivals ends up on different teams. People are numbered 0 to n − 1, and rivalries are undirected pairs. Write `canSplit(_ n: Int, _ rivalries: [(Int, Int)]) -> Bool`. It must work when the rivalry graph has several components, and run in O(n + number of rivalries).

  Expected output for the starter's calls:

  ```output
  true false true true
  ```
starter: |
  func canSplit(_ n: Int, _ rivalries: [(Int, Int)]) -> Bool {
      return false
  }

  print(
      canSplit(4, [(0, 1), (1, 2), (2, 3), (3, 0)]),
      canSplit(3, [(0, 1), (1, 2), (2, 0)]),
      canSplit(5, [(0, 1), (2, 3)]),
      canSplit(1, [])
  )
hints:
  - Give the first person team 0. Their rivals must be team 1, the rivals' rivals team 0, and so on.
  - Run BFS and assign each newly discovered person the opposite team of the person who discovered them.
  - If you ever see an edge between two people already on the same team, it's impossible.
  - Start a new BFS from every person who has no team yet, to cover all components.
rubric:
  - Builds an undirected adjacency list.
  - Colors with BFS or DFS, giving each neighbor the opposite team.
  - Detects a conflict when a neighbor already has the same team.
  - Loops over all vertices to handle every component.
  - States O(V + E) time and O(V) space.
solution: |
  ```swift
  func canSplit(_ n: Int, _ rivalries: [(Int, Int)]) -> Bool {
      var adjacency = Array(repeating: [Int](), count: n)
      for (a, b) in rivalries {
          adjacency[a].append(b)
          adjacency[b].append(a)
      }
      var team = [Int?](repeating: nil, count: n)
      for start in 0..<n where team[start] == nil {
          team[start] = 0
          var queue = [start]
          var head = 0
          while head < queue.count {
              let person = queue[head]
              head += 1
              for rival in adjacency[person] {
                  if let rivalTeam = team[rival] {
                      if rivalTeam == team[person] { return false }
                  } else {
                      team[rival] = 1 - team[person]!
                      queue.append(rival)
                  }
              }
          }
      }
      return true
  }

  print(
      canSplit(4, [(0, 1), (1, 2), (2, 3), (3, 0)]),
      canSplit(3, [(0, 1), (1, 2), (2, 0)]),
      canSplit(5, [(0, 1), (2, 3)]),
      canSplit(1, [])
  )
  ```

  ```output
  true false true true
  ```

  This is a **two-coloring** of the graph (the graph is called **bipartite** when it works). Once one person's team is fixed, BFS forces every other person in the component: rivals get the opposite team. A conflict means some rival pair got the same team, which happens exactly when the component contains a cycle of odd length, like the triangle in the second call. The outer loop starts a new BFS in every component, since the third call has two separate rivalries and a person with none. Each person is enqueued once and each rivalry examined twice: **O(n + E)** time, O(n + E) space for the adjacency list.
````

````exercise
id: m19-l05-e6
type: solve
prompt: |
  A map of a lake region is a grid of `"L"` (land) and `"W"` (water). An island is a group of land cells connected up, down, left or right. Write `islands(_ rows: [String]) -> (count: Int, largest: Int)` that returns the number of islands and the size of the largest one, in O(rows × columns).

  Expected output for the starter's calls:

  ```output
  3 4
  0 0
  1 5
  ```
starter: |
  func islands(_ rows: [String]) -> (count: Int, largest: Int) {
      return (0, 0)
  }

  let map = ["LLWW", "LWWL", "WWLL", "LWWL"]
  let a = islands(map), b = islands(["WWW"]), c = islands(["LLL", "LWL"])
  print(a.count, a.largest)
  print(b.count, b.largest)
  print(c.count, c.largest)
hints:
  - Each island is a connected component of land cells.
  - Scan every cell. When you find land that isn't visited yet, that's a new island; flood it with BFS or DFS and count its cells.
  - Mark cells when you push them, and check bounds before indexing.
rubric:
  - Treats the grid as an implicit graph with four neighbor offsets.
  - Starts a traversal from every unvisited land cell and counts each as one island.
  - Counts the cells of each island and keeps the maximum.
  - "Visits each cell a constant number of times: O(rows × columns) time and space."
solution: |
  ```swift
  func islands(_ rows: [String]) -> (count: Int, largest: Int) {
      let grid = rows.map { Array($0) }
      guard let width = grid.first?.count else { return (0, 0) }
      let height = grid.count
      var visited = Array(repeating: Array(repeating: false, count: width), count: height)
      var count = 0
      var largest = 0
      for r in 0..<height {
          for c in 0..<width where grid[r][c] == "L" && !visited[r][c] {
              count += 1
              var size = 0
              var stack = [(r, c)]
              visited[r][c] = true
              while let (cr, cc) = stack.popLast() {
                  size += 1
                  for (dr, dc) in [(-1, 0), (1, 0), (0, -1), (0, 1)] {
                      let nr = cr + dr, nc = cc + dc
                      guard nr >= 0, nr < height, nc >= 0, nc < width else { continue }
                      guard grid[nr][nc] == "L", !visited[nr][nc] else { continue }
                      visited[nr][nc] = true
                      stack.append((nr, nc))
                  }
              }
              largest = max(largest, size)
          }
      }
      return (count, largest)
  }

  let map = ["LLWW", "LWWL", "WWLL", "LWWL"]
  let a = islands(map), b = islands(["WWW"]), c = islands(["LLL", "LWL"])
  print(a.count, a.largest)
  print(b.count, b.largest)
  print(c.count, c.largest)
  ```

  ```output
  3 4
  0 0
  1 5
  ```

  This is connected components on an implicit graph. The outer loops find the first cell of each island; the stack-based flood fill marks and counts the rest of it, so every cell is pushed at most once and checked from at most four neighbors: **O(rows × columns)**. In the first map the islands are the top-left three cells, the right-hand group (1,3), (2,2), (2,3), (3,3) with four cells, and the single cell at (3,0).
````

## Summary

- A **graph** is vertices plus edges, directed or undirected, with no root and possibly cycles. Trees are the special case with no cycles.
- Use an **adjacency list** (O(V + E) space) for sparse graphs, which is almost all of them; an **adjacency matrix** (O(V²)) only for small dense graphs or O(1) edge checks.
- Every graph traversal needs a **visited set**. BFS marks on enqueue.
- **BFS** with a queue visits by distance and finds **shortest paths in unweighted graphs**; record parents to rebuild the path. **DFS** with recursion or a stack goes deep first and finds *a* path, not the shortest.
- Both are **O(V + E)** time and O(V) extra space with an adjacency list.
- **Connected components**: start a traversal from every unvisited vertex; each start is a new component.
- A **grid** is an implicit graph: compute neighbors with direction offsets, check bounds first, and use a 2D visited array.
