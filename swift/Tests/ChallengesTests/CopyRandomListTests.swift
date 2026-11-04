import Testing
@testable import Challenges

/// Deterministic pseudo-random numbers (a 64-bit LCG), so a failing case reproduces.
private struct SeededGenerator {
    var state: UInt64
    mutating func next(below bound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
}

/// Builds a list from values and, for each node, the index its `random` points to (or nil).
/// Returns the nodes so the test keeps them alive (`random` is weak).
private func makeList(_ values: [Int], randoms: [Int?]) -> [RandomListNode] {
    let nodes = values.map { RandomListNode($0) }
    for index in nodes.indices.dropLast() {
        nodes[index].next = nodes[index + 1]
    }
    for (index, target) in randoms.enumerated() {
        nodes[index].random = target.map { nodes[$0] }
    }
    return nodes
}

private func nodes(_ head: RandomListNode?) -> [RandomListNode] {
    var result: [RandomListNode] = []
    var current = head
    while let node = current {
        result.append(node)
        current = node.next
    }
    return result
}

/// The list's shape: each node's value and the index its `random` points to.
private func shape(_ head: RandomListNode?) -> [String] {
    let all = nodes(head)
    return all.map { node in
        let target = node.random.flatMap { random in all.firstIndex { $0 === random } }
        return "\(node.value)->\(target.map(String.init) ?? "nil")"
    }
}

private typealias Copier = @Sendable (RandomListNode?) -> RandomListNode?

private let copiers: [(String, Copier)] = [
    ("dictionary", copyRandomList),
    ("interleaved", copyRandomListInterleaved),
    ("brute force", copyRandomListBruteForce),
]

@Suite("Copy List with Random Pointer")
struct CopyRandomListTests {
    @Test("Example from the problem statement", arguments: copiers.map(\.0))
    func example(name: String) throws {
        let copy = try #require(copiers.first { $0.0 == name }).1
        let original = makeList([7, 13, 11, 10, 1], randoms: [nil, 0, 4, 2, 0])
        let result = copy(original.first)
        #expect(shape(result) == ["7->nil", "13->0", "11->4", "10->2", "1->0"])
    }

    @Test("Empty list", arguments: copiers.map(\.0))
    func empty(name: String) throws {
        let copy = try #require(copiers.first { $0.0 == name }).1
        #expect(copy(nil) == nil)
    }

    @Test("A node whose random points to itself", arguments: copiers.map(\.0))
    func selfPointer(name: String) throws {
        let copy = try #require(copiers.first { $0.0 == name }).1
        let original = makeList([4, 5], randoms: [0, 1])
        let result = copy(original.first)
        let copied = nodes(result)
        #expect(copied.count == 2)
        #expect(copied[0].random === copied[0])
        #expect(copied[1].random === copied[1])
    }

    @Test("The copy shares no nodes with the original, and the original is unchanged", arguments: copiers.map(\.0))
    func deepAndNonDestructive(name: String) throws {
        let copy = try #require(copiers.first { $0.0 == name }).1
        let original = makeList([1, 2, 3, 4], randoms: [3, nil, 1, 1])
        let shapeBefore = shape(original.first)
        let result = copy(original.first)
        let originalIDs = Set(original.map(ObjectIdentifier.init))
        let copied = nodes(result)
        #expect(copied.allSatisfy { !originalIDs.contains(ObjectIdentifier($0)) })
        #expect(copied.allSatisfy { node in node.random.map { !originalIDs.contains(ObjectIdentifier($0)) } ?? true })
        #expect(shape(original.first) == shapeBefore)
        #expect(nodes(original.first).count == 4)
        #expect(shape(result) == shapeBefore)
    }

    @Test("Random lists keep their shape with every version")
    func randomShapes() {
        var generator = SeededGenerator(state: 13)
        for _ in 0..<300 {
            let count = generator.next(below: 10)
            let values = (0..<count).map { _ in generator.next(below: 5) }
            let randoms: [Int?] = (0..<count).map { _ in
                let pick = generator.next(below: count + 1)
                return pick == count ? nil : pick
            }
            let original = makeList(values, randoms: randoms)
            let expected = shape(original.first)
            for (name, copy) in copiers {
                let result = copy(original.first)
                #expect(shape(result) == expected, "\(name), values: \(values), randoms: \(randoms)")
                #expect(shape(original.first) == expected)
            }
        }
    }
}
