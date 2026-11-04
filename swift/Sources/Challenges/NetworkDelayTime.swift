/// Returns how long a message sent from `source` takes to reach every one of the `nodeCount` relays
/// (numbered from 0), or `nil` if some relay can't be reached. Each link is one-way and takes
/// `delay` milliseconds, never negative. The answer is the arrival time at the relay reached last.
///
/// Dijkstra's algorithm with a binary min-heap. The heap may hold stale entries for a relay whose
/// time later improved; they're skipped when popped ("lazy deletion"), which is simpler than a heap
/// that supports decrease-key. O((V + E) log V) time, O(V + E) space.
public func signalDelay(nodeCount: Int, links: [(from: Int, to: Int, delay: Int)], source: Int) -> Int? {
    var outgoing = [[(to: Int, delay: Int)]](repeating: [], count: nodeCount)
    for link in links {
        outgoing[link.from].append((link.to, link.delay))
    }

    var arrival = [Int?](repeating: nil, count: nodeCount)
    var heap = SignalHeap()
    heap.push((time: 0, node: source))
    while let (time, node) = heap.pop() {
        if arrival[node] != nil { continue }   // already settled with a time no larger than this
        arrival[node] = time
        for edge in outgoing[node] where arrival[edge.to] == nil {
            heap.push((time: time + edge.delay, node: edge.to))
        }
    }

    var latest = 0
    for time in arrival {
        guard let time else { return nil }
        latest = max(latest, time)
    }
    return latest
}

/// A min-heap of (time, node) pairs ordered by time.
struct SignalHeap {
    private var storage: [(time: Int, node: Int)] = []

    mutating func push(_ entry: (time: Int, node: Int)) {
        storage.append(entry)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard storage[child].time < storage[parent].time else { return }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> (time: Int, node: Int)? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let removed = storage.removeLast()
        var parent = 0
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var smallest = parent
            if left < storage.count && storage[left].time < storage[smallest].time { smallest = left }
            if right < storage.count && storage[right].time < storage[smallest].time { smallest = right }
            if smallest == parent { break }
            storage.swapAt(parent, smallest)
            parent = smallest
        }
        return removed
    }
}

/// Naive solution: Bellman–Ford. Relax every link V - 1 times; after round i, every relay reachable
/// with at most i links has its best time. O(V · E) time, O(V) space.
public func signalDelayBellmanFord(nodeCount: Int, links: [(from: Int, to: Int, delay: Int)], source: Int) -> Int? {
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
