import Testing
@testable import Challenges

extension MaxPathNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> MaxPathNode { MaxPathNode(value) }
}

@Suite("Binary Tree Maximum Path Sum")
struct BinaryTreeMaximumPathSumTests {
    private func best(_ values: [Int?]) -> Int {
        let root: MaxPathNode? = buildTestTree(values)
        return maxPathSum(root!)
    }

    /// Independent check: the path between every pair of nodes, found through parent links.
    private func bestByAllPairs(_ root: MaxPathNode) -> Int {
        var nodes: [MaxPathNode] = []
        var parent: [ObjectIdentifier: MaxPathNode] = [:]
        var pending = [root]
        while let node = pending.popLast() {
            nodes.append(node)
            for child in [node.left, node.right].compactMap({ $0 }) {
                parent[ObjectIdentifier(child)] = node
                pending.append(child)
            }
        }
        func ancestors(_ node: MaxPathNode) -> [MaxPathNode] {
            var chain = [node]
            while let up = parent[ObjectIdentifier(chain.last!)] { chain.append(up) }
            return chain
        }
        var best = Int.min
        for a in nodes {
            let upFromA = ancestors(a)
            let idsFromA = Set(upFromA.map(ObjectIdentifier.init))
            for b in nodes {
                let upFromB = ancestors(b)
                let meetIndex = upFromB.firstIndex { idsFromA.contains(ObjectIdentifier($0)) }!
                let meet = upFromB[meetIndex]
                let aSide = upFromA.prefix { $0 !== meet }.reduce(0) { $0 + $1.value }
                let bSide = upFromB[..<meetIndex].reduce(0) { $0 + $1.value }
                best = max(best, aSide + bSide + meet.value)
            }
        }
        return best
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(best([2, 1, 3]) == 6)
        #expect(best([-8, 9, 20, nil, nil, 15, 7]) == 42)
        #expect(best([5, 4, 8, 11, nil, 13, 4, 7, 2, nil, nil, nil, 1]) == 48)
    }

    @Test("Every value is negative: the answer is the largest single node")
    func allNegative() {
        #expect(best([-3]) == -3)
        #expect(best([-2, -1, -5]) == -1)
    }

    @Test("The best path skips the root")
    func skipsRoot() {
        #expect(best([-10, 4, -20, 6, 7]) == 17)
    }

    @Test("A path can end at an inner node")
    func endsInside() {
        #expect(best([10, -50, -50, 1]) == 10)
    }

    @Test("Agrees with the brute force and with every pair of endpoints")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 72)
        for size in 1..<60 {
            let root: MaxPathNode? = randomTestTree(count: size, values: -10...10, using: &generator)
            let fast = maxPathSum(root!)
            #expect(fast == maxPathSumBruteForce(root!))
            #expect(fast == bestByAllPairs(root!))
        }
    }
}
