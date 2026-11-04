import Testing
@testable import Challenges

extension RecoverBSTNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> RecoverBSTNode { RecoverBSTNode(value) }
}

@Suite("Recover Binary Search Tree")
struct RecoverBinarySearchTreeTests {
    private func recovered(_ values: [Int?]) -> [Int?] {
        let root: RecoverBSTNode? = buildTestTree(values)
        recoverBinarySearchTree(root)
        return testTreeLevelOrder(root)
    }

    @Test("Examples from the problem statement")
    func examples() {
        // 20 and 30 swapped: not neighbors in sorted order.
        #expect(recovered([30, 10, 25, 5, 15, nil, 20]) == [20, 10, 25, 5, 15, nil, 30])
        // 10 and 15 swapped: neighbors in sorted order, so only one drop.
        #expect(recovered([20, 15, 30, 5, 10]) == [20, 10, 30, 5, 15])
    }

    @Test("The root is one of the swapped nodes")
    func rootSwapped() {
        #expect(recovered([1, 2]) == [2, 1])
        #expect(recovered([3, 1, 2]) == [2, 1, 3])
    }

    @Test("Shape never changes")
    func shapeUnchanged() {
        let root: RecoverBSTNode? = buildTestTree([4, 2, 6, 1, 7, 5, 3])
        let leftBefore = root?.left
        recoverBinarySearchTree(root)
        #expect(root?.left === leftBefore)
        #expect(testTreeInorderValues(root) == [1, 2, 3, 4, 5, 6, 7])
    }

    @Test("Fixes every possible swap in random BSTs")
    func randomSwaps() {
        var generator = TreeChallengeLCG(seed: 70)
        for _ in 0..<40 {
            let count = generator.next(in: 2...20)
            let root: RecoverBSTNode? = randomTestTree(count: count, values: 0...0, using: &generator)
            // Write 0, 10, 20... in inorder so the random shape becomes a valid BST.
            var nodes: [RecoverBSTNode] = []
            func collect(_ node: RecoverBSTNode?) {
                guard let node else { return }
                collect(node.left)
                nodes.append(node)
                collect(node.right)
            }
            collect(root)
            for (index, node) in nodes.enumerated() { node.value = index * 10 }
            let expected = testTreeLevelOrder(root)

            for i in nodes.indices {
                for j in nodes.indices where i < j {
                    (nodes[i].value, nodes[j].value) = (nodes[j].value, nodes[i].value)
                    let copy = copyTestTree(root)
                    recoverBinarySearchTree(root)
                    #expect(testTreeLevelOrder(root) == expected)
                    recoverBinarySearchTreeBySorting(copy)
                    #expect(testTreeLevelOrder(copy) == expected)
                }
            }
        }
    }
}
