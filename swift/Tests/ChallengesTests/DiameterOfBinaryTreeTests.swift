import Testing
@testable import Challenges

extension DiameterTreeNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> DiameterTreeNode { DiameterTreeNode(value) }
}

@Suite("Diameter of Binary Tree")
struct DiameterOfBinaryTreeTests {
    private func diameter(_ values: [Int?]) -> Int {
        diameterOfBinaryTree(buildTestTree(values))
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(diameter([1, 2, 3, 4, 5]) == 3)
        #expect(diameter([1, 2]) == 1)
    }

    @Test("Empty tree and single node")
    func tiny() {
        #expect(diameter([]) == 0)
        #expect(diameter([9]) == 0)
    }

    @Test("The longest path doesn't go through the root")
    func notThroughRoot() {
        // The root has a single left child; the long path bends lower down.
        let values: [Int?] = [1, 2, nil, 3, 4, 5, nil, nil, 6, 7, nil, nil, 8]
        #expect(diameter(values) == 6)
    }

    @Test("A chain counts every edge")
    func chain() {
        #expect(diameter([1, 2, nil, 3, nil, 4]) == 3)
    }

    @Test("Agrees with the brute force on random trees")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 65)
        for size in 0..<120 {
            let root: DiameterTreeNode? = randomTestTree(count: size, values: 0...9, using: &generator)
            #expect(diameterOfBinaryTree(root) == diameterOfBinaryTreeBruteForce(root))
        }
    }
}
