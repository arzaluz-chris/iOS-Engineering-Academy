---
id: eventual-safe-states
title: Eventual Safe States
difficulty: medium
order: 80
patterns: [Directed graph, Topological sort, Cycle detection]
prerequisites: [m19-l05, m19-l06]
summary: Which states of a directed graph can never reach a cycle? Kahn's algorithm, run backward from the dead ends, answers it in one pass.
solutionFile: EventualSafeStates.swift
testFile: EventualSafeStatesTests.swift
starter: |
  func eventualSafeStates(_ graph: [[Int]]) -> [Int] {
      // Your solution
      return []
  }
time: O(V + E)
space: O(V + E)
edgeCases:
  - Empty graph
  - A self-loop (a state that can move to itself)
  - A state with one move to a dead end and another into a cycle
  - A state outside a cycle that points into it
  - Duplicate moves to the same state
askInterviewer:
  - Does "safe" mean every path ends, or that some path ends?
  - Can a state move to itself? Can the same move appear twice?
  - Should the result be sorted?
hints:
  - Which states are obviously safe? Which are obviously unsafe?
  - A state is safe when all of its moves lead to safe states. That sounds like the in-degree countdown in Kahn's algorithm, but on which edges?
  - Reverse the edges. Start from the dead ends, and each time a state is proven safe, tell the states that point to it.
followUps:
  - Solve it with a three-color DFS instead. What color does a state end in when it's safe?
  - Return one cycle that makes a state unsafe.
  - Where does this show up in an app? (A navigation or state machine where some states can loop forever.)
rubric:
  - I defined safe precisely and identified dead ends as the starting point.
  - I counted unresolved outgoing moves per state and decremented them through the reversed edges.
  - I explained why states that can reach a cycle never reach a count of 0.
  - I gave O(V + E) time and space.
codeStatus: tested
---

An onboarding flow is a directed graph of screens: `graph[s]` lists the screens you can go to from screen `s`. Some screens are terminal (no moves out). A product review wants to know which screens are **safe**: no matter what the user taps from there, they'll eventually reach a terminal screen. A screen is unsafe if some sequence of taps from it can loop forever.

Write `eventualSafeStates(_:)`, which returns every safe state in ascending order.

```swift
//  0 → 1, 0 → 2
//  1 → 3        3 → 0     (0 → 1 → 3 → 0 is a cycle)
//  2 → 5        4 → 5
//  5 and 6 are terminal
eventualSafeStates([[1, 2], [3], [5], [0], [5], [], []])  // [2, 4, 5, 6]
eventualSafeStates([[1], [2], []])                        // [0, 1, 2]
eventualSafeStates([[0]])                                 // []: a self-loop is a cycle
```

**Constraints:** `0 ≤ V ≤ 10^4`; `0 ≤ E ≤ 4 · 10^4`; moves point to valid states.

<!-- reveal -->

## First approach

A terminal state is safe. A state is safe if every one of its moves goes to a safe state. A state that can reach a cycle is unsafe, because a user can take that route and go around forever. So safety flows backward from the terminal states, the same way readiness flows forward from states with no prerequisites in the topological sort lesson.

## Naive solution

For each state separately, run a depth-first search from it and look for a cycle: a move back to a state that's still on the current path.

```swift
func eventualSafeStates(_ graph: [[Int]]) -> [Int] {
    func reachesCycle(from start: Int) -> Bool {
        var onPath = [Bool](repeating: false, count: graph.count)
        var finished = [Bool](repeating: false, count: graph.count)
        func visit(_ state: Int) -> Bool {
            if onPath[state] { return true }
            if finished[state] { return false }
            onPath[state] = true
            for target in graph[state] where visit(target) { return true }
            onPath[state] = false
            finished[state] = true
            return false
        }
        return visit(start)
    }
    return graph.indices.filter { !reachesCycle(from: $0) }
}
```

## Problems with the naive solution

Each search is O(V + E), and there's one per state: O(V · (V + E)). With 10^4 states and 4 · 10^4 moves, that's around 5 · 10^8 steps. The searches repeat each other: once a state is known to be safe or unsafe, every later search through it could reuse the answer. It also recurses as deep as the longest path, up to V calls.

## Optimized solution

Run Kahn's algorithm on the reversed graph. For each state, count its outgoing moves that haven't been proven safe (`unresolved`). Terminal states start at 0, so they're ready. Each time a state is proven safe, go to every state that has a move to it (the reversed edges) and decrement its count. A state whose count reaches 0 has only safe moves, so it's safe too. States that can reach a cycle never get to 0: the cycle's states each wait on another state in the cycle, so none of them goes first. Every edge is processed once: O(V + E), and no recursion.

## Line by line

- `var predecessors`: the reversed graph. `predecessors[t]` lists the states with a move to `t`. A duplicate move appears twice here, which matches its two entries in `unresolved`.
- `var unresolved = graph.map(\.count)`: outgoing moves per state not yet proven safe.
- `var ready = graph.indices.filter { unresolved[$0] == 0 }`: the terminal states.
- `while let state = ready.popLast()`: the order states come off doesn't matter, so a stack (the end of an array) works as well as a queue.
- `isSafe[state] = true`: every move from it leads somewhere safe.
- `unresolved[predecessor] -= 1; if unresolved[predecessor] == 0 { ready.append(predecessor) }`: the predecessor's last unresolved move just resolved.
- `return graph.indices.filter { isSafe[$0] }`: walking the indices in order gives the ascending result without sorting.

## Common mistakes

- Using "some path ends" instead of "every path ends", which marks state 0 in the first example as safe because it can reach 5.
- Running Kahn's algorithm on the original edges. That removes states with no incoming edges, which answers a different question (which states are not reachable from a cycle).
- Detecting cycles with a single visited set in the DFS version. The cycle-detection exercise in the topological sort lesson shows why that reports cycles that aren't there.

## Variation

**Three-color DFS:** mark a state gray while it's on the current path and black when it's finished. A move into a gray state is a cycle, and every gray state on the path at that moment is unsafe. A state that finishes black without finding a cycle is safe, and later searches can stop at it immediately. Each state is visited once: O(V + E).
