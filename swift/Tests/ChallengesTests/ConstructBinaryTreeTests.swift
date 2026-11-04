import Testing
@testable import Challenges

extension BuildTreeNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> BuildTreeNode { BuildTreeNode(value) }
}

@Suite("Construct Binary Tree from Preorder and Inorder")
struct ConstructBinaryTreeTests {
    private func preorder(_ node: BuildTreeNode?) -> [Int] {
        guard let node else { return [] }
        return [node.value] + preorder(node.left) + preorder(node.right)
    }

    @Test("Examples from the problem statement")
    func examples() {
        let root = buildTree(preorder: [3, 9, 20, 15, 7], inorder: [9, 3, 15, 20, 7])
        #expect(testTreeLevelOrder(root) == [3, 9, 20, nil, nil, 15, 7])
        #expect(testTreeLevelOrder(buildTree(preorder: [1, 2], inorder: [1, 2])) == [1, nil, 2])
        #expect(buildTree(preorder: [], inorder: []) == nil)
    }

    @Test("A single node")
    func singleNode() {
        #expect(testTreeLevelOrder(buildTree(preorder: [-4], inorder: [-4])) == [-4])
    }

    @Test("Chains to the left and to the right")
    func chains() {
        #expect(testTreeLevelOrder(buildTree(preorder: [1, 2, 3], inorder: [3, 2, 1])) == [1, 2, nil, 3])
        #expect(testTreeLevelOrder(buildTree(preorder: [1, 2, 3], inorder: [1, 2, 3])) == [1, nil, 2, nil, 3])
    }

    @Test("Rebuilds random trees exactly, and agrees with the slicing version")
    func roundTrip() {
        var generator = TreeChallengeLCG(seed: 71)
        for size in 0..<80 {
            let shape: BuildTreeNode? = randomTestTree(count: size, values: 0...0, using: &generator)
            // Give the nodes distinct values in an order unrelated to the shape.
            var pool = Array(0..<size).map { $0 * 7 - 100 }
            var pending: [BuildTreeNode] = shape.map { [$0] } ?? []
            while let node = pending.popLast() {
                node.value = pool.remove(at: generator.next(in: 0...(pool.count - 1)))
                if let left = node.left { pending.append(left) }
                if let right = node.right { pending.append(right) }
            }
            let pre = preorder(shape)
            let ino = testTreeInorderValues(shape)
            let expected = testTreeLevelOrder(shape)
            #expect(testTreeLevelOrder(buildTree(preorder: pre, inorder: ino)) == expected)
            #expect(testTreeLevelOrder(buildTreeBySlicing(preorder: pre, inorder: ino)) == expected)
        }
    }
}
