---
id: network-delay-time
title: Network Delay Time
difficulty: medium
order: 81
patterns: [Weighted graph, Dijkstra, Heap]
prerequisites: [m19-l04, m19-l05]
summary: How long until a message reaches every relay, when each link has its own delay? BFS stops working with weights; Dijkstra's algorithm swaps its queue for a priority queue.
solutionFile: NetworkDelayTime.swift
testFile: NetworkDelayTimeTests.swift
starter: |
  func signalDelay(nodeCount: Int, links: [(from: Int, to: Int, delay: Int)], source: Int) -> Int? {
      // Your solution
      return nil
  }
time: O((V + E) log V)
space: O(V + E)
edgeCases:
  - A single relay (the answer is 0)
  - A relay that can't be reached
  - One-way links
  - Zero-delay links, duplicate links between the same pair, and cycles
  - A direct link that's slower than a detour
askInterviewer:
  - Are links one-way or two-way?
  - Can a delay be zero, or negative?
  - What do I return if some relay is unreachable?
  - Can there be several links between the same two relays?
hints:
  - The graphs lesson in Module 19 said BFS gives shortest distances only when every edge costs the same. Find a small example where BFS's answer is wrong here.
  - Always settle the relay with the smallest known arrival time next. Why can't anything later make that relay's time smaller, if delays are never negative?
  - You need "the smallest known time" over and over while times keep getting added. You built that structure in the heaps lesson.
followUps:
  - What goes wrong with negative delays, and which algorithm handles them? (Bellman–Ford.)
  - Return the actual fastest route to a given relay. (Store each relay's predecessor.)
  - If every delay is 0 or 1, how can you avoid the heap? (0-1 BFS with a deque.)
rubric:
  - I explained why plain BFS fails with weights.
  - I implemented Dijkstra with a min-heap and skipped stale entries.
  - I returned the maximum of the shortest times, and nil when something is unreachable.
  - I stated the complexity and the non-negative weight requirement.
codeStatus: tested
---

A chat backend broadcasts a message from one relay server to all the others. Relays are numbered `0..<nodeCount`. Each link is **one-way** and takes `delay` milliseconds (never negative). A relay forwards the message on all its links as soon as it first receives it.

Write `signalDelay(nodeCount:links:source:)`, which returns how long it takes for every relay to receive the message sent from `source`: the arrival time of the relay that gets it last. Return `nil` if some relay never receives it.

```swift
let links = [(from: 0, to: 1, delay: 4), (from: 0, to: 2, delay: 1),
             (from: 2, to: 1, delay: 2), (from: 1, to: 3, delay: 5)]
signalDelay(nodeCount: 4, links: links, source: 0)  // 8: 0 → 2 → 1 arrives at 3, then 1 → 3 at 8
signalDelay(nodeCount: 4, links: links, source: 1)  // nil: nothing links back to 0 or 2
signalDelay(nodeCount: 1, links: [], source: 0)     // 0
```

**Constraints:** `1 ≤ nodeCount ≤ 100`; `0 ≤ links.count ≤ 6,000`; `0 ≤ delay ≤ 100`.

<!-- reveal -->

## First approach

Every relay's arrival time is its shortest-path distance from the source, where a path's length is the sum of its delays. The answer is the largest of those distances. BFS finds shortest paths by number of edges, which is wrong here: in the example, the direct link 0 → 1 takes 4, but 0 → 2 → 1 takes 3. You need an algorithm for weighted shortest paths.

## Naive solution

Bellman–Ford: start with 0 for the source and "unknown" for everyone else, then go through every link, and whenever a link gives a relay an earlier arrival, take it. After V − 1 rounds every shortest path, which has at most V − 1 links, has been found.

```swift
func signalDelay(nodeCount: Int, links: [(from: Int, to: Int, delay: Int)], source: Int) -> Int? {
    var arrival = [Int?](repeating: nil, count: nodeCount)
    arrival[source] = 0
    for _ in 0..<max(0, nodeCount - 1) {
        var changed = false
        for link in links {
            guard let start = arrival[link.from] else { continue }
            let candidate = start + link.delay
            if arrival[link.to].map({ candidate < $0 }) ?? true {
                arrival[link.to] = candidate
                changed = true
            }
        }
        if !changed { break }
    }
    var latest = 0
    for time in arrival {
        guard let time else { return nil }
        latest = max(latest, time)
    }
    return latest
}
```

## Problems with the naive solution

Each round looks at every link, and there can be V − 1 rounds: O(V · E). With these constraints that's about 600,000 relaxations, which runs fine; at a million links and thousands of relays, it doesn't. Its advantage is that it tolerates negative delays, which Dijkstra doesn't. Say that: it's the reason Bellman–Ford still exists.

## Optimized solution

Dijkstra's algorithm. Keep a min-heap of `(time, relay)` candidates, starting with `(0, source)`. Pop the earliest. If that relay already has a final time, this entry is stale; skip it. Otherwise this is its final time: with no negative delays, any other route to it would go through a relay popped later, which already has a time at least as large. Then push a candidate for each neighbor that isn't settled yet.

The heap can hold several entries for the same relay, from different routes. Skipping the stale ones when they're popped ("lazy deletion") is simpler than a heap that can lower an entry's key, and costs only a log factor on the extra entries.

## Line by line

- `var outgoing`: an adjacency list built from the links, so each relay's links are found in O(1).
- `var arrival = [Int?](repeating: nil, count: nodeCount)`: `nil` means "not settled yet".
- `heap.push((time: 0, node: source))`: the source receives the message at time 0.
- `while let (time, node) = heap.pop()`: the earliest candidate.
- `if arrival[node] != nil { continue }`: stale. The relay was settled earlier with a time no larger than this one.
- `arrival[node] = time`: final.
- `for edge in outgoing[node] where arrival[edge.to] == nil`: pushing candidates for settled relays would only create more stale entries.
- The final loop returns `nil` for any unsettled relay and otherwise the largest arrival time.
- `SignalHeap`: the array-based min-heap from the heaps lesson, ordered by `time`.

## Common mistakes

- Using plain BFS, or a FIFO queue, and getting the edge-count distance instead of the time.
- Marking a relay as settled when it's **pushed** instead of when it's **popped**. A later, cheaper route can still arrive before it's popped.
- Returning the sum of the arrival times, or the time to one particular relay, instead of the maximum.
- Running Dijkstra with negative delays. It doesn't crash; it silently returns wrong answers.

## Variation

**Cheapest flight with at most k stops:** the number of links used now matters as well as the price. Bellman–Ford limited to k + 1 rounds (each round reading the previous round's prices) handles it directly; Dijkstra needs the stop count as part of the state.
