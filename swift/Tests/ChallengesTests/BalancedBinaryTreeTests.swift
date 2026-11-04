import Testing
@testable import Challenges

extension BalancedTreeNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> BalancedTreeNode { BalancedTreeNode(value) }
}

@Suite("Balanced Binary Tree")
struct BalancedBinaryTreeTests {
    private func balanced(_ values: [Int?]) -> Bool {
        isBalancedTree(buildTestTree(values))
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(balanced([3, 9, 20, nil, nil, 15, 7]))
        #expect(!balanced([1, 2, nil, 3]))
        #expect(balanced([]))
    }

    @Test("Balanced at the root but not lower down")
    func imbalanceBelowRoot() {
        // Both subtrees of the root have height 2, but each one is a chain.
        #expect(!balanced([1, 2, 3, 4, nil, nil, 5, 6, nil, nil, 7]))
    }

    @Test("A difference of exactly one is fine")
    func differenceOfOne() {
        #expect(balanced([1, 2, 3, 4]))
        #expect(balanced([1, 2]))
    }

    @Test("A single node is balanced")
    func singleNode() {
        #expect(balanced([1]))
    }

    @Test("Agrees with the top-down version on random trees")
    func agreesWithTopDown() {
        var generator = TreeChallengeLCG(seed: 66)
        var balancedCount = 0
        for size in 0..<300 {
            let root: BalancedTreeNode? = randomTestTree(count: size % 12, values: 0...9, using: &generator)
            let fast = isBalancedTree(root)
            #expect(fast == isBalancedTreeTopDown(root))
            if fast { balancedCount += 1 }
        }
        // Make sure the random trees exercise both answers.
        #expect(balancedCount > 20 && balancedCount < 280)
    }
}
