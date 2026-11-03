---
id: m19-l06
title: Topological sort
description: You order the vertices of a directed acyclic graph so every edge points forward, using Kahn's algorithm (in-degrees and a queue) and a DFS that records vertices as they finish; you detect cycles with both, split a build into stages that can run in parallel, and solve the course-prerequisites problem.
module: m19
order: 6
level: intermediate
minutes: 65
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m19-l05]
objectives:
  - Define a topological order and explain why it exists exactly when a directed graph has no cycle.
  - Implement Kahn's algorithm with in-degrees and a queue, and use it to detect cycles.
  - Implement a DFS-based topological sort with three vertex states, and explain why reversed finish order works.
  - Group vertices into stages that can be processed in parallel.
  - Model dependency problems (builds, course prerequisites, setup steps) as graphs with the right edge direction.
terms:
  - term: Directed acyclic graph (DAG)
    definition: A directed graph with no directed cycle. Dependency graphs should be DAGs.
  - term: Topological order
    definition: An ordering of a directed graph's vertices where, for every edge u → v, u comes before v. It exists if and only if the graph is a DAG.
  - term: In-degree
    definition: The number of edges pointing into a vertex. In a dependency graph with edges from prerequisite to dependent, it's the number of unmet prerequisites.
  - term: Kahn's algorithm
    definition: A topological sort that repeatedly removes a vertex with in-degree 0, appends it to the order and decrements its successors' in-degrees.
  - term: Back edge
    definition: In a DFS of a directed graph, an edge to a vertex that's still on the current path. Finding one proves the graph has a cycle.
mastery:
  - Turn a list of "X depends on Y" facts into a graph with edges Y → X.
  - Write Kahn's algorithm and report a cycle when fewer than V vertices come out.
  - Write a DFS topological sort with unvisited, in-progress and done states, and detect a cycle from a back edge.
  - Split a DAG into parallel stages with a level-by-level Kahn's algorithm.
  - State O(V + E) for both algorithms and explain why topological orders aren't unique.
resources: [swift-dictionary, swift-array, swift-set, swift-book-enumerations]
cards:
  - id: m19-l06-c1
    front: When does a directed graph have a topological order?
    back: "Exactly when it has no directed cycle (it's a DAG). In a cycle, every vertex would have to come before itself."
  - id: m19-l06-c2
    front: Describe Kahn's algorithm in two sentences.
    back: "Compute every vertex's in-degree and enqueue those with 0. Repeatedly dequeue a vertex, append it to the order, and decrement its successors' in-degrees, enqueuing any that reach 0."
  - id: m19-l06-c3
    front: How does Kahn's algorithm detect a cycle?
    back: "Vertices on a cycle never reach in-degree 0, so they're never output. If the order has fewer than V vertices, the graph has a cycle."
  - id: m19-l06-c4
    front: Why does DFS cycle detection in a directed graph need three states instead of a visited flag?
    back: "Reaching a finished vertex again is fine (a diamond A→B→D, A→C→D). Only reaching a vertex that's still on the current path (in progress) means a cycle."
  - id: m19-l06-c5
    front: "In a dependency graph, which way should the edge point for \"Feed depends on Networking\"?"
    back: "Networking → Feed, from the prerequisite to the dependent, so the topological order lists Networking first. Pointing it the other way gives the reverse order."
---

## The idea in one sentence

A topological sort lists the steps of a job so that **every step comes after everything it depends on**, and it's possible exactly when the dependencies don't go in a circle.

## Dependencies are a directed graph

An app is split into Swift packages or modules: `Core`, `Networking` (depends on `Core`), `DesignSystem` (depends on `Core`), `Feed` (depends on `Networking` and `DesignSystem`), `Settings` (depends on `DesignSystem`), and `App` (depends on `Feed` and `Settings`). In what order can they be built?

Draw each module as a vertex and each dependency as an edge **from the prerequisite to the module that needs it**:

```text
         Core
        /    \
       v      v
 Networking  DesignSystem
       \      /     \
        v    v       v
         Feed      Settings
            \      /
             v    v
              App
```

A **topological order** lists the vertices so that for every edge u → v, u comes before v. `Core, Networking, DesignSystem, Feed, Settings, App` is one; `Core, DesignSystem, Settings, Networking, Feed, App` is another. There's usually more than one, because nothing forces an order between independent modules like `Networking` and `DesignSystem`.

A topological order exists **if and only if** the graph has no directed cycle. If `Core` depended on `App`, there'd be a cycle Core → Networking → Feed → App → Core, and each of them would have to be built before itself. A graph with no directed cycle is a **DAG**, a directed acyclic graph. Build systems, Xcode's target dependencies, package managers, spreadsheet recalculation, task schedulers and course catalogs all rely on dependencies forming a DAG, and they all have to report an error when they don't.

> [!tip] Get the edge direction right first
> "Feed depends on Networking" becomes the edge Networking → Feed. If you store it as Feed → Networking, every algorithm below still runs, and gives you the **reverse** order. Decide the direction once, write it in a comment, and build the graph from it.

## Kahn's algorithm

Kahn's algorithm builds the order from the front. A vertex with **in-degree 0** (no incoming edges, so no unmet dependencies) can go first. Output it, remove its outgoing edges, which lowers its successors' in-degrees, and repeat with whatever reaches 0.

```swift
func kahn(_ names: [String], _ edges: [(Int, Int)]) -> [String]? {
    var successors = Array(repeating: [Int](), count: names.count)
    var inDegree = Array(repeating: 0, count: names.count)
    for (from, to) in edges {
        successors[from].append(to)
        inDegree[to] += 1
    }

    var queue = (0..<names.count).filter { inDegree[$0] == 0 }
    var head = 0
    while head < queue.count {
        let vertex = queue[head]
        head += 1
        for next in successors[vertex] {
            inDegree[next] -= 1
            if inDegree[next] == 0 { queue.append(next) }
        }
    }
    guard queue.count == names.count else { return nil }
    return queue.map { names[$0] }
}

let modules = ["Core", "Networking", "DesignSystem", "Feed", "Settings", "App"]
let dependsOn = [(0, 1), (0, 2), (1, 3), (2, 3), (2, 4), (3, 5), (4, 5)]
print(kahn(modules, dependsOn) ?? ["cycle"])
print(kahn(modules, dependsOn + [(5, 0)]) ?? ["cycle"])
```

```output
["Core", "Networking", "DesignSystem", "Feed", "Settings", "App"]
["cycle"]
```

1. One pass over the edges builds the adjacency list and the in-degrees. The pair `(from, to)` means "from must come before to".
2. Every vertex with in-degree 0 starts in the queue. Here that's only `Core`.
3. Taking `Core` lowers `Networking` and `DesignSystem` to 0, so both are enqueued. Taking `Networking` lowers `Feed` to 1, not 0: `Feed` still waits for `DesignSystem`. Taking `DesignSystem` releases `Feed` and `Settings`.
4. The queue (with a head index, Module 17) ends up holding the order itself.
5. With the extra edge App → Core, `Core` has in-degree 1 and no vertex starts at 0. The queue is empty, the order has 0 of 6 vertices, and the function reports the cycle.

**Why it detects cycles.** A vertex on a cycle has an incoming edge from the previous vertex of the cycle, and that vertex can't be output before it, so none of them ever reaches in-degree 0. Vertices that merely depend on a cycle are stuck too. So "fewer than V vertices output" means "there's a cycle", and the stuck vertices (in-degree still above 0) tell you where to look.

**Cost.** Building the graph is O(V + E). Each vertex is enqueued once, and each edge decrements one in-degree once: **O(V + E)** time, O(V + E) space.

Any vertex with in-degree 0 may go next; the queue just picks the oldest. Using the priority queue from Lesson 4 instead would give the lexicographically smallest order, at O((V + E) log V).

## Building in parallel stages

Kahn's algorithm also answers a better question: which modules can be built **at the same time**? Process it in rounds, like the level-order traversal in the first lesson: everything with in-degree 0 at the start of a round is independent and can build in parallel.

```swift
func stages(_ names: [String], _ edges: [(Int, Int)]) -> [[String]]? {
    var successors = Array(repeating: [Int](), count: names.count)
    var inDegree = Array(repeating: 0, count: names.count)
    for (from, to) in edges {
        successors[from].append(to)
        inDegree[to] += 1
    }

    var current = (0..<names.count).filter { inDegree[$0] == 0 }
    var result: [[String]] = []
    var output = 0
    while !current.isEmpty {
        result.append(current.map { names[$0] })
        output += current.count
        var next: [Int] = []
        for vertex in current {
            for successor in successors[vertex] {
                inDegree[successor] -= 1
                if inDegree[successor] == 0 { next.append(successor) }
            }
        }
        current = next
    }
    return output == names.count ? result : nil
}

let modules = ["Core", "Networking", "DesignSystem", "Feed", "Settings", "App", "Analytics"]
let dependsOn = [(0, 1), (0, 2), (1, 3), (2, 3), (2, 4), (3, 5), (4, 5), (6, 5)]
for (number, stage) in (stages(modules, dependsOn) ?? []).enumerated() {
    print("Stage \(number + 1):", stage.joined(separator: ", "))
}
```

```output
Stage 1: Core, Analytics
Stage 2: Networking, DesignSystem
Stage 3: Feed, Settings
Stage 4: App
```

`Analytics` has no dependencies, so it builds in the first stage alongside `Core`. The number of stages is the length of the longest dependency chain, so with enough parallel workers, that chain, not the number of modules, decides the build time. Same O(V + E) cost.

## Topological sort with DFS

The second method comes from DFS. When a DFS on a DAG **finishes** a vertex (returns from it after exploring all its successors), every vertex that must come after it has already finished. So the **finish order, reversed**, is a topological order.

For cycle detection, a "visited" flag isn't enough. Each vertex is in one of three states:

- **unvisited**,
- **in progress**: entered, but not finished; it's on the current DFS path,
- **done**: finished.

An edge to an **in-progress** vertex points back up the current path: that's a **back edge**, and it closes a cycle. An edge to a **done** vertex is fine: that vertex was fully explored through another route, as in a diamond.

```swift
enum State {
    case unvisited, inProgress, done
}

func topologicalOrder(_ names: [String], _ edges: [(Int, Int)]) -> [String]? {
    var successors = Array(repeating: [Int](), count: names.count)
    for (from, to) in edges {
        successors[from].append(to)
    }
    var state = Array(repeating: State.unvisited, count: names.count)
    var finished: [Int] = []
    var hasCycle = false

    func visit(_ vertex: Int) {
        state[vertex] = .inProgress
        for next in successors[vertex] {
            switch state[next] {
            case .unvisited:
                visit(next)
            case .inProgress:
                hasCycle = true
            case .done:
                break
            }
            if hasCycle { return }
        }
        state[vertex] = .done
        finished.append(vertex)
    }

    for vertex in 0..<names.count where state[vertex] == .unvisited {
        visit(vertex)
        if hasCycle { return nil }
    }
    return finished.reversed().map { names[$0] }
}

let modules = ["Core", "Networking", "DesignSystem", "Feed", "Settings", "App"]
let dependsOn = [(0, 1), (0, 2), (1, 3), (2, 3), (2, 4), (3, 5), (4, 5)]
print(topologicalOrder(modules, dependsOn) ?? ["cycle"])
print(topologicalOrder(modules, dependsOn + [(5, 2)]) ?? ["cycle"])
print(topologicalOrder(["A", "B"], [(0, 1), (1, 0)]) ?? ["cycle"])
```

```output
["Core", "DesignSystem", "Settings", "Networking", "Feed", "App"]
["cycle"]
["cycle"]
```

Trace the first call. `visit(Core)` goes to `Networking`, then `Feed`, then `App`. `App` has no successors, so it finishes first. Back in `Feed`, which finishes; then `Networking`. Back in `Core`, the next successor is `DesignSystem`: its edge to `Feed` hits a **done** vertex, which is fine, and its edge to `Settings` explores `Settings`, whose edge to `App` also hits a done vertex. Finish order: App, Feed, Networking, Settings, DesignSystem, Core. Reversed, it's a valid order, different from Kahn's but just as correct.

With the extra edge App → DesignSystem, the DFS goes Core → Networking → Feed → App → DesignSystem. The first successor of `DesignSystem` is `Feed`, which is still **in progress**: a back edge. The cycle is Feed → App → DesignSystem → Feed.

**Why reversed finish order works.** Take any edge u → v. When the DFS examines that edge from u, v is either unvisited (then it's visited and finishes before u finishes), or done (it finished earlier). It can't be in progress in a DAG, because that would be a cycle. Either way v finishes before u, so in the reversed list u comes before v.

**Cost.** Each vertex is visited once and each edge examined once: **O(V + E)**. The recursion depth can reach V, so for very large graphs use Kahn's algorithm or an explicit stack.

## Which one to use

Both are O(V + E). Kahn's algorithm is iterative, makes cycle detection a single count comparison, and gives parallel stages for free; it's the usual choice for build and task scheduling. The DFS version is natural when you're already doing a DFS, when you want to report the actual cycle (the in-progress vertices are the current path, so the cycle is the part of the path from the repeated vertex on), or when you only need the order of what's reachable from one vertex, like "what must be built before `App`?".

## Common mistakes

> [!error] Edges in the wrong direction
> Storing "A depends on B" as A → B gives the reverse of the build order. Neither algorithm will complain. Fix the convention before writing code, and test with one obvious pair.

> [!error] Not checking for leftover vertices in Kahn's algorithm
> Returning the queue without comparing its length to V silently drops every vertex on or behind a cycle. That's a missing module in the build, not an error message.

> [!error] A single visited flag for directed cycle detection
> In a diamond (A → B, A → C, B → D, C → D), D is reached twice without any cycle. With one flag you report a cycle that isn't there; with "visited means skip" you miss real cycles. Use three states.

> [!error] Using the undirected cycle test on a directed graph
> In an undirected graph, "a visited neighbor that isn't my parent" means a cycle. In a directed graph that rule is wrong; only an in-progress vertex means a cycle.

> [!error] Expecting one specific order
> Many orders can be valid. Tests should check the property (every edge points forward) rather than compare to a single array, unless you've fixed the tie-breaking.

## Exercises

````exercise
id: m19-l06-e1
type: comprehension
prompt: "A setup flow has steps with dependencies: Account → Profile, Account → Permissions, Profile → Done, Permissions → Done (an arrow means \"must happen before\"). Which statement is true?"
choices:
  - text: "Both Account, Profile, Permissions, Done and Account, Permissions, Profile, Done are valid topological orders."
    correct: true
    why: In both, every arrow points forward. Profile and Permissions don't depend on each other.
  - text: The graph has a cycle because Done can be reached by two different paths.
    correct: false
    why: Two paths to the same vertex is a diamond, not a cycle. A cycle would need a path from a vertex back to itself.
  - text: "Done, Profile, Permissions, Account is a valid order, read from the end."
    correct: false
    why: That's the reverse order. Every edge would point backward.
  - text: There's exactly one valid order, because Kahn's algorithm is deterministic.
    correct: false
    why: The algorithm picks one, depending on the queue order, but the graph allows two.
solution: |
  **Both orders are valid.** A topological order only requires each edge to point forward. Account must be first and Done last, but Profile and Permissions are independent, so either can come first. The two paths into Done make it a diamond, which is perfectly acyclic; in Kahn's algorithm, Done just starts with in-degree 2 and waits for both.
````

````exercise
id: m19-l06-e2
type: prediction
prompt: "Predict the exact output. Edges are (from, to): from must come before to."
code: |
  let names = ["a", "b", "c", "d", "e"]
  let edges = [(3, 0), (3, 1), (0, 2), (1, 2), (4, 1)]

  var successors = Array(repeating: [Int](), count: names.count)
  var inDegree = Array(repeating: 0, count: names.count)
  for (from, to) in edges {
      successors[from].append(to)
      inDegree[to] += 1
  }
  print(inDegree)

  var queue = (0..<names.count).filter { inDegree[$0] == 0 }
  var head = 0
  while head < queue.count {
      let vertex = queue[head]
      head += 1
      for next in successors[vertex] {
          inDegree[next] -= 1
          if inDegree[next] == 0 { queue.append(next) }
      }
  }
  print(queue.map { names[$0] }.joined())
output: |
  [1, 2, 2, 0, 0]
  deabc
hints:
  - "In-degrees: a has one incoming edge (from d), b has two (d and e), c has two (a and b)."
  - "The initial queue is in index order: d (3), then e (4)."
  - "Processing d lowers a to 0 and b to 1. Processing e lowers b to 0."
solution: |
  ```output
  [1, 2, 2, 0, 0]
  deabc
  ```

  Only d and e start with in-degree 0, and `filter` keeps index order, so the queue starts `[d, e]`. Dequeue d: a drops to 0 (enqueued), b drops to 1. Dequeue e: b drops to 0 (enqueued). Dequeue a: c drops to 1. Dequeue b: c drops to 0 (enqueued). Dequeue c. All five came out, so there's no cycle, and the order is d, e, a, b, c.
````

````exercise
id: m19-l06-e3
type: find-errors
prompt: This function tries to detect a cycle in a directed graph with DFS and a single visited set. Which statements are true?
code: |
  func hasCycle(_ successors: [[Int]]) -> Bool {
      var visited = Set<Int>()
      func visit(_ vertex: Int) -> Bool {
          if visited.contains(vertex) { return true }
          visited.insert(vertex)
          for next in successors[vertex] {
              if visit(next) { return true }
          }
          return false
      }
      for vertex in 0..<successors.count where !visited.contains(vertex) {
          if visit(vertex) { return true }
      }
      return false
  }
choices:
  - text: "It reports a cycle for the diamond 0 → 1, 0 → 2, 1 → 3, 2 → 3, which has none."
    correct: true
    why: "Vertex 3 is visited through 1, then reached again through 2, and \"already visited\" is treated as a cycle."
  - text: It needs a third state, in progress, so that only edges back to the current path count as cycles.
    correct: true
    why: That's exactly the distinction between a back edge and an edge to a finished vertex.
  - text: It misses the cycle 0 → 1 → 0.
    correct: false
    why: "From 0 it visits 1, and 1's edge back to 0 finds 0 in visited, so it returns true."
  - text: It's O(V²) because of the Set.
    correct: false
    why: "Set operations are O(1) on average. The problem is correctness, not cost."
rubric:
  - I found the false positive on a diamond.
  - I explained the difference between an in-progress vertex and a finished one.
  - I fixed it with three states and tested it on a diamond and on a real cycle.
solution: |
  The function confuses "seen before" with "on the current path". Fix it with three states, and mark a vertex done when its exploration ends:

  ```swift
  func hasCycle(_ successors: [[Int]]) -> Bool {
      var inProgress = Set<Int>()
      var done = Set<Int>()
      func visit(_ vertex: Int) -> Bool {
          if inProgress.contains(vertex) { return true }
          if done.contains(vertex) { return false }
          inProgress.insert(vertex)
          for next in successors[vertex] {
              if visit(next) { return true }
          }
          inProgress.remove(vertex)
          done.insert(vertex)
          return false
      }
      for vertex in 0..<successors.count where !done.contains(vertex) {
          if visit(vertex) { return true }
      }
      return false
  }

  print(hasCycle([[1, 2], [3], [3], []]))
  print(hasCycle([[1], [0]]))
  print(hasCycle([[1], [2], [3], [1]]))
  ```

  ```output
  false
  true
  true
  ```

  In the diamond, vertex 3 is done by the time 2 reaches it, so it's skipped. In the last graph, the cycle 1 → 2 → 3 → 1 doesn't include vertex 0, and the DFS from 0 still finds it because 1 is in progress when 3 points back to it.
````

````exercise
id: m19-l06-e4
type: fill-in
prompt: Complete Kahn's algorithm so the program prints `["wake", "shower", "coffee", "dress", "leave"]` and then `nil`.
code: |
  func order(_ names: [String], _ edges: [(Int, Int)]) -> [String]? {
      var successors = Array(repeating: [Int](), count: names.count)
      var inDegree = Array(repeating: 0, count: names.count)
      for (from, to) in edges {
          successors[from].append(to)
          inDegree[[[1]]] += 1
      }
      var queue = (0..<names.count).filter { inDegree[$0] == [[2]] }
      var head = 0
      while head < queue.count {
          let vertex = queue[head]
          head += 1
          for next in successors[vertex] {
              inDegree[next] -= 1
              if inDegree[next] == 0 { queue.append([[3]]) }
          }
      }
      return queue.count == [[4]] ? queue.map { names[$0] } : nil
  }

  let steps = ["wake", "shower", "coffee", "dress", "leave"]
  print(order(steps, [(0, 1), (0, 2), (1, 3), (3, 4), (2, 4)]) ?? [])
  print(order(steps, [(0, 1), (1, 0)]) as Any)
blanks:
  - id: "1"
    answers: ["to"]
  - id: "2"
    answers: ["0"]
  - id: "3"
    answers: ["next"]
  - id: "4"
    answers: ["names.count"]
solution: |
  ```swift
  func order(_ names: [String], _ edges: [(Int, Int)]) -> [String]? {
      var successors = Array(repeating: [Int](), count: names.count)
      var inDegree = Array(repeating: 0, count: names.count)
      for (from, to) in edges {
          successors[from].append(to)
          inDegree[to] += 1
      }
      var queue = (0..<names.count).filter { inDegree[$0] == 0 }
      var head = 0
      while head < queue.count {
          let vertex = queue[head]
          head += 1
          for next in successors[vertex] {
              inDegree[next] -= 1
              if inDegree[next] == 0 { queue.append(next) }
          }
      }
      return queue.count == names.count ? queue.map { names[$0] } : nil
  }

  let steps = ["wake", "shower", "coffee", "dress", "leave"]
  print(order(steps, [(0, 1), (0, 2), (1, 3), (3, 4), (2, 4)]) ?? [])
  print(order(steps, [(0, 1), (1, 0)]) as Any)
  ```

  ```output
  ["wake", "shower", "coffee", "dress", "leave"]
  nil
  ```

  The in-degree counts incoming edges, so it's incremented on the edge's target. The queue starts with in-degree 0 vertices, and a successor is enqueued when its last prerequisite is done. If fewer than `names.count` vertices come out, some are stuck on a cycle. In the second call, wake and shower wait for each other, and coffee, dress and leave come out but the total is 3 of 5, so the result is `nil`. `as Any` prints the optional without the compiler's warning about implicitly converting it.
````

````exercise
id: m19-l06-e5
type: solve
prompt: |
  A learning app has `n` courses numbered 0 to n − 1 and a list of prerequisite pairs `(course, prerequisite)`: to take `course` you must first finish `prerequisite`. Write `studyPlan(_ n: Int, _ prerequisites: [(Int, Int)]) -> [Int]?` that returns an order in which all courses can be taken, or `nil` if that's impossible. When several courses are available at once, take the lowest-numbered one first, so the answer is unique. O((n + P) log n) is fine.

  Expected output for the starter's calls:

  ```output
  [0, 1, 2, 3]
  nil
  [1, 2, 0, 3]
  [0, 1, 2]
  ```
starter: |
  func studyPlan(_ n: Int, _ prerequisites: [(Int, Int)]) -> [Int]? {
      return nil
  }

  print(studyPlan(4, [(1, 0), (2, 0), (3, 1), (3, 2)]).map { "\($0)" } ?? "nil")
  print(studyPlan(2, [(0, 1), (1, 0)]).map { "\($0)" } ?? "nil")
  print(studyPlan(4, [(0, 2), (3, 0), (2, 1)]).map { "\($0)" } ?? "nil")
  print(studyPlan(3, []).map { "\($0)" } ?? "nil")
hints:
  - "The pair (course, prerequisite) is the edge prerequisite → course. Watch the order inside the tuple."
  - Kahn's algorithm with a plain queue gives a valid order but not necessarily the lowest-numbered-first one.
  - "Keep the available courses in a min-heap (or, for small n, pick the minimum from a sorted list each time)."
rubric:
  - Builds edges from prerequisite to course, not the other way around.
  - Uses in-degrees and always takes the smallest available course.
  - Returns nil when fewer than n courses can be ordered.
  - States the cost and why a heap is needed for the tie-breaking rule.
solution: |
  ```swift
  func studyPlan(_ n: Int, _ prerequisites: [(Int, Int)]) -> [Int]? {
      var unlocks = Array(repeating: [Int](), count: n)
      var inDegree = Array(repeating: 0, count: n)
      for (course, prerequisite) in prerequisites {
          unlocks[prerequisite].append(course)
          inDegree[course] += 1
      }

      var heap: [Int] = []
      func push(_ value: Int) {
          heap.append(value)
          var child = heap.count - 1
          while child > 0 && heap[child] < heap[(child - 1) / 2] {
              heap.swapAt(child, (child - 1) / 2)
              child = (child - 1) / 2
          }
      }
      func pop() -> Int {
          heap.swapAt(0, heap.count - 1)
          let smallest = heap.removeLast()
          var parent = 0
          while true {
              let left = 2 * parent + 1, right = left + 1
              var first = parent
              if left < heap.count && heap[left] < heap[first] { first = left }
              if right < heap.count && heap[right] < heap[first] { first = right }
              if first == parent { break }
              heap.swapAt(parent, first)
              parent = first
          }
          return smallest
      }

      for course in 0..<n where inDegree[course] == 0 { push(course) }
      var plan: [Int] = []
      while !heap.isEmpty {
          let course = pop()
          plan.append(course)
          for next in unlocks[course] {
              inDegree[next] -= 1
              if inDegree[next] == 0 { push(next) }
          }
      }
      return plan.count == n ? plan : nil
  }

  print(studyPlan(4, [(1, 0), (2, 0), (3, 1), (3, 2)]).map { "\($0)" } ?? "nil")
  print(studyPlan(2, [(0, 1), (1, 0)]).map { "\($0)" } ?? "nil")
  print(studyPlan(4, [(0, 2), (3, 0), (2, 1)]).map { "\($0)" } ?? "nil")
  print(studyPlan(3, []).map { "\($0)" } ?? "nil")
  ```

  ```output
  [0, 1, 2, 3]
  nil
  [1, 2, 0, 3]
  [0, 1, 2]
  ```

  The tuple says `(course, prerequisite)`, so the edge goes from the second element to the first: finishing the prerequisite **unlocks** the course. With a FIFO queue the third call would still be valid, but "lowest-numbered first" needs the smallest available course each time, which is what the min-heap from Lesson 4 gives. Each course is pushed and popped once, O(log n) each, and each prerequisite pair is processed once: **O((n + P) log n)**. If fewer than n courses come out, some courses wait on each other in a cycle and the plan is impossible.
````

````exercise
id: m19-l06-e6
type: explain
prompt: |
  Explain to a colleague why reversing the order in which DFS **finishes** vertices gives a valid topological order of a DAG, and why the same algorithm needs an extra check on a graph that might have a cycle.
code: |
  func visit(_ vertex: Int) {
      state[vertex] = .inProgress
      for next in successors[vertex] where state[next] == .unvisited {
          visit(next)
      }
      state[vertex] = .done
      finished.append(vertex)
  }
  // order = finished.reversed()
rubric:
  - Considers an arbitrary edge u → v and the state of v when DFS examines the edge from u.
  - Shows that v finishes before u whether v was unvisited or already done.
  - Explains that v can't be in progress in a DAG, because that would be a cycle.
  - Concludes that reversed finish order puts u before v for every edge.
  - Explains that with a cycle the reversed order still exists but some edge points backward, so you must detect in-progress vertices and report the cycle.
solution: |
  Pick any edge u → v and look at the moment DFS examines it, while u is in progress. There are three possibilities for v. If v is **unvisited**, DFS visits it right now, inside u's call, so v finishes before u does. If v is **done**, it already finished, so again before u. If v were **in progress**, it would be on the current path, which means there's a path v → … → u, and with the edge u → v that's a cycle; in a DAG it can't happen. So for every edge, v finishes before u, and reversing the finish order puts u before v. That's the definition of a topological order.

  On a graph with a cycle, the DFS still finishes every vertex and the reversed list still exists, but the edge that closed the cycle points backward in it, so it isn't a topological order, and nothing in the list tells you. That's why the algorithm tracks the in-progress state: hitting an in-progress vertex is exactly the third case above, a back edge, and it's the signal to stop and report the cycle instead of returning a wrong order.
````

## Summary

- A **topological order** puts every edge u → v with u first. It exists exactly when the directed graph has no cycle (a **DAG**), and it's usually not unique.
- Model "B depends on A" as the edge **A → B**. The wrong direction silently gives the reverse order.
- **Kahn's algorithm**: in-degrees, a queue of in-degree 0 vertices, decrement successors. Fewer than V vertices out means a cycle. Processing in rounds gives **parallel stages**.
- **DFS**: record vertices as they finish and reverse. Three states (unvisited, in progress, done); an edge to an in-progress vertex is a **back edge**, which means a cycle.
- Both are **O(V + E)**. A priority queue instead of a FIFO queue gives the smallest order under a tie-breaking rule, at an extra log factor.
