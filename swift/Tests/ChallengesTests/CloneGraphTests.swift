import Testing
@testable import Challenges

@Suite("Clone Graph")
struct CloneGraphTests {
    /// Builds nodes 0..<n with the given neighbor lists and returns all of them.
    private func makeGraph(_ adjacency: [[Int]]) -> [CloneGraphNode] {
        let nodes = adjacency.indices.map { CloneGraphNode($0) }
        for (index, neighbors) in adjacency.enumerated() {
            nodes[index].neighbors = neighbors.map { nodes[$0] }
        }
        return nodes
    }

    /// Breaks the reference cycles so the test doesn't leak.
    private func tearDown(_ start: CloneGraphNode?) {
        guard let start else { return }
        var seen: Set<ObjectIdentifier> = [ObjectIdentifier(start)]
        var pending = [start]
        while let node = pending.popLast() {
            for neighbor in node.neighbors where seen.insert(ObjectIdentifier(neighbor)).inserted {
                pending.append(neighbor)
            }
            node.neighbors = []
        }
    }

    /// Walks both graphs in lockstep. Returns false if values, neighbor order or shape differ, if
    /// the copy shares any object with the original, or if a node maps to two different copies.
    private func isFaithfulCopy(_ original: CloneGraphNode?, _ copy: CloneGraphNode?) -> Bool {
        guard let original, let copy else { return original == nil && copy == nil }
        var copyFor: [ObjectIdentifier: CloneGraphNode] = [ObjectIdentifier(original): copy]
        var originals: Set<ObjectIdentifier> = [ObjectIdentifier(original)]
        var pending = [(original, copy)]
        while let (from, to) = pending.popLast() {
            guard from !== to, from.value == to.value, from.neighbors.count == to.neighbors.count
            else { return false }
            for (neighbor, neighborCopy) in zip(from.neighbors, to.neighbors) {
                let key = ObjectIdentifier(neighbor)
                if let known = copyFor[key] {
                    if known !== neighborCopy { return false }
                } else {
                    copyFor[key] = neighborCopy
                    originals.insert(key)
                    pending.append((neighbor, neighborCopy))
                }
            }
        }
        // No copy may be one of the originals.
        return copyFor.values.allSatisfy { !originals.contains(ObjectIdentifier($0)) }
    }

    @Test("Examples from the problem statement")
    func examples() {
        // A square: 0-1, 1-2, 2-3, 3-0.
        let square = makeGraph([[1, 3], [0, 2], [1, 3], [2, 0]])
        let copy = cloneGraph(square[0])
        #expect(isFaithfulCopy(square[0], copy))
        #expect(copy?.neighbors.map(\.value) == [1, 3])
        tearDown(square[0])
        tearDown(copy)
    }

    @Test("Empty graph and a single node")
    func tiny() {
        #expect(cloneGraph(nil) == nil)
        let lonely = CloneGraphNode(7)
        let copy = cloneGraph(lonely)
        #expect(copy !== lonely)
        #expect(copy?.value == 7)
        #expect(copy?.neighbors.isEmpty == true)
    }

    @Test("Two nodes pointing at each other")
    func pair() {
        let pair = makeGraph([[1], [0]])
        let copy = cloneGraph(pair[0])
        #expect(isFaithfulCopy(pair[0], copy))
        #expect(copy?.neighbors[0].neighbors[0] === copy)
        tearDown(pair[0])
        tearDown(copy)
    }

    @Test("Only the part reachable from the start is copied")
    func reachableOnly() {
        let graph = makeGraph([[1], [0], [3], [2]])
        let copy = cloneGraph(graph[0])
        var count = 0
        var seen: Set<ObjectIdentifier> = []
        var pending = [copy!]
        while let node = pending.popLast() {
            guard seen.insert(ObjectIdentifier(node)).inserted else { continue }
            count += 1
            pending.append(contentsOf: node.neighbors)
        }
        #expect(count == 2)
        tearDown(graph[0])
        tearDown(graph[2])
        tearDown(copy)
    }

    @Test("Both versions copy random connected graphs faithfully")
    func randomGraphs() {
        var generator = TreeChallengeLCG(seed: 79)
        for _ in 0..<80 {
            let count = generator.next(in: 1...15)
            var adjacency = [[Int]](repeating: [], count: count)
            func link(_ a: Int, _ b: Int) {
                guard a != b, !adjacency[a].contains(b) else { return }
                adjacency[a].append(b)
                adjacency[b].append(a)
            }
            for node in 1..<max(1, count) { link(node, generator.next(in: 0...(node - 1))) }
            for _ in 0..<generator.next(in: 0...(2 * count)) {
                link(generator.next(in: 0...(count - 1)), generator.next(in: 0...(count - 1)))
            }
            let graph = makeGraph(adjacency)
            let fast = cloneGraph(graph[0])
            let slow = cloneGraphWithLinearLookup(graph[0])
            #expect(isFaithfulCopy(graph[0], fast))
            #expect(isFaithfulCopy(graph[0], slow))
            tearDown(graph[0])
            tearDown(fast)
            tearDown(slow)
        }
    }
}
