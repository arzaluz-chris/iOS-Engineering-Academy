import Testing
@testable import Challenges

extension ZigzagTreeNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> ZigzagTreeNode { ZigzagTreeNode(value) }
}

@Suite("Zigzag Level Order")
struct ZigzagLevelOrderTests {
    private func zigzag(_ values: [Int?]) -> [[Int]] {
        zigzagLevelOrder(buildTestTree(values))
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(zigzag([1, 2, 3, 4, 5, 6, 7]) == [[1], [3, 2], [4, 5, 6, 7]])
        #expect(zigzag([8, 3, nil, 1, 6, nil, nil, 4]) == [[8], [3], [1, 6], [4]])
        #expect(zigzag([]) == [])
    }

    @Test("A single node")
    func singleNode() {
        #expect(zigzag([42]) == [[42]])
    }

    @Test("Missing children in the middle of a level")
    func gaps() {
        #expect(zigzag([1, 2, 3, nil, 4, 5, nil, 6, nil, nil, 7]) == [[1], [3, 2], [4, 5], [7, 6]])
    }

    @Test("Agrees with the level-by-depth version on random trees")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 69)
        for size in 0..<100 {
            let root: ZigzagTreeNode? = randomTestTree(count: size, values: 0...99, using: &generator)
            #expect(zigzagLevelOrder(root) == zigzagLevelOrderByDepth(root))
        }
    }
}
