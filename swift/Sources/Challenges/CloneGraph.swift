/// A vertex of an undirected graph for the Clone Graph challenge. Neighbors are strong references,
/// so a graph with an edge is a reference cycle; see the card's follow-ups.
public final class CloneGraphNode {
    public var value: Int
    public var neighbors: [CloneGraphNode]

    public init(_ value: Int, neighbors: [CloneGraphNode] = []) {
        self.value = value
        self.neighbors = neighbors
    }
}

/// Returns a deep copy of the connected graph that contains `node`: new objects with the same
/// values and the same edges, in the same neighbor order, sharing nothing with the original.
///
/// A dictionary from each original node's `ObjectIdentifier` to its copy does two jobs: it's the
/// visited set for a breadth-first walk, and it finds the copy of any neighbor in O(1).
/// O(V + E) time, O(V) space.
public func cloneGraph(_ node: CloneGraphNode?) -> CloneGraphNode? {
    guard let node else { return nil }
    var copies: [ObjectIdentifier: CloneGraphNode] = [ObjectIdentifier(node): CloneGraphNode(node.value)]
    var queue = [node]
    var head = 0
    while head < queue.count {
        let original = queue[head]
        head += 1
        let copy = copies[ObjectIdentifier(original)]!
        for neighbor in original.neighbors {
            let key = ObjectIdentifier(neighbor)
            if copies[key] == nil {
                copies[key] = CloneGraphNode(neighbor.value)
                queue.append(neighbor)
            }
            copy.neighbors.append(copies[key]!)
        }
    }
    return copies[ObjectIdentifier(node)]
}

/// Naive solution: collect the originals in an array, make one copy per position, then wire each
/// edge by searching the array for the neighbor's position with `firstIndex(where:)`.
/// O(V · (V + E)) time, O(V) space.
public func cloneGraphWithLinearLookup(_ node: CloneGraphNode?) -> CloneGraphNode? {
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
