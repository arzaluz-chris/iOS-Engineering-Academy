import Testing
@testable import Challenges

extension InvertTreeNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> InvertTreeNode { InvertTreeNode(value) }
}

@Suite("Invert Binary Tree")
struct InvertBinaryTreeTests {
    private func inverted(_ values: [Int?]) -> [Int?] {
        let root: InvertTreeNode? = buildTestTree(values)
        return testTreeLevelOrder(invertTree(root))
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(inverted([4, 2, 7, 1, 3, 6, 9]) == [4, 7, 2, 9, 6, 3, 1])
        #expect(inverted([2, 1, 3]) == [2, 3, 1])
        #expect(inverted([]) == [])
    }

    @Test("A single node stays the same")
    func singleNode() {
        #expect(inverted([5]) == [5])
    }

    @Test("A left chain becomes a right chain")
    func chain() {
        #expect(inverted([1, 2, nil, 3]) == [1, nil, 2, nil, 3])
    }

    @Test("Returns the same root object, mirrored in place")
    func sameRoot() {
        let root: InvertTreeNode? = buildTestTree([1, 2, 3])
        let result = invertTree(root)
        #expect(result === root)
        #expect(root?.left?.value == 3)
    }

    @Test("A very deep chain doesn't use the call stack")
    func deepChain() {
        let root = InvertTreeNode(0)
        var tail = root
        for value in 1..<100_000 {
            let next = InvertTreeNode(value)
            tail.left = next
            tail = next
        }
        _ = invertTree(root)
        var depth = 0
        var cursor: InvertTreeNode? = root
        while let node = cursor {
            #expect(node.left == nil)
            depth += 1
            cursor = node.right
        }
        #expect(depth == 100_000)
        // Releasing a 100,000-node chain all at once would recurse through deinit; cut it up first.
        cursor = root
        while let node = cursor {
            cursor = node.right
            node.right = nil
        }
    }

    @Test("Inverting twice gives back the original")
    func twiceIsIdentity() {
        var generator = TreeChallengeLCG(seed: 63)
        for size in 0..<40 {
            let root: InvertTreeNode? = randomTestTree(count: size, values: -9...9, using: &generator)
            let before = testTreeLevelOrder(root)
            #expect(testTreeLevelOrder(invertTree(invertTree(root))) == before)
        }
    }

    @Test("Iterative and recursive versions agree")
    func agreesWithRecursive() {
        var generator = TreeChallengeLCG(seed: 6_363)
        for size in 0..<60 {
            let root: InvertTreeNode? = randomTestTree(count: size, values: 0...20, using: &generator)
            let copy = copyTestTree(root)
            #expect(testTreeLevelOrder(invertTree(root)) == testTreeLevelOrder(invertTreeRecursive(copy)))
        }
    }
}
