/// Returns, in ascending order, every safe state of a directed graph. `graph[v]` lists the states
/// that v can move to. A state is safe when every path that starts there ends at a state with no
/// outgoing moves, so no path from it can go around a cycle forever.
///
/// Work backward from the dead ends, like Kahn's algorithm on the reversed graph. A state with no
/// outgoing moves is safe. Each time a state is found safe, every state that points to it has one
/// fewer unresolved move; a state whose moves are all resolved is safe too. States that can reach a
/// cycle never get there. O(V + E) time and space.
public func eventualSafeStates(_ graph: [[Int]]) -> [Int] {
    var predecessors = [[Int]](repeating: [], count: graph.count)
    var unresolved = graph.map(\.count)
    for (state, targets) in graph.enumerated() {
        for target in targets {
            predecessors[target].append(state)
        }
    }

    var ready = graph.indices.filter { unresolved[$0] == 0 }
    var isSafe = [Bool](repeating: false, count: graph.count)
    while let state = ready.popLast() {
        isSafe[state] = true
        for predecessor in predecessors[state] {
            unresolved[predecessor] -= 1
            if unresolved[predecessor] == 0 { ready.append(predecessor) }
        }
    }
    return graph.indices.filter { isSafe[$0] }
}

/// Naive solution: for each state, run a fresh depth-first search from it and look for a cycle
/// (a move back to a state still on the current path). O(V · (V + E)) time, O(V) space.
public func eventualSafeStatesBruteForce(_ graph: [[Int]]) -> [Int] {
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
