import Testing
@testable import Challenges

extension BSTAncestorNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> BSTAncestorNode { BSTAncestorNode(value) }
}

@Suite("Lowest Common Ancestor in a BST")
struct LowestCommonAncestorBSTTests {
    private func insert(_ value: Int, into root: BSTAncestorNode?) -> BSTAncestorNode {
        guard let root else { return BSTAncestorNode(value) }
        if value < root.value {
            root.left = insert(value, into: root.left)
        } else if value > root.value {
            root.right = insert(value, into: root.right)
        }
        return root
    }

    private let example: [Int?] = [20, 10, 30, 5, 15, 25, 40, nil, nil, 12, 18]

    @Test("Examples from the problem statement")
    func examples() {
        let root: BSTAncestorNode? = buildTestTree(example)
        #expect(lowestCommonAncestorInBST(root, 12, 18)?.value == 15)
        #expect(lowestCommonAncestorInBST(root, 5, 18)?.value == 10)
        #expect(lowestCommonAncestorInBST(root, 12, 40)?.value == 20)
        #expect(lowestCommonAncestorInBST(root, 10, 12)?.value == 10)
    }

    @Test("One value is an ancestor of the other")
    func ancestorOfTheOther() {
        let root: BSTAncestorNode? = buildTestTree(example)
        #expect(lowestCommonAncestorInBST(root, 30, 25)?.value == 30)
        #expect(lowestCommonAncestorInBST(root, 20, 18)?.value == 20)
    }

    @Test("Both values are the same node")
    func sameValue() {
        let root: BSTAncestorNode? = buildTestTree(example)
        #expect(lowestCommonAncestorInBST(root, 12, 12)?.value == 12)
    }

    @Test("Order of the two values doesn't matter")
    func argumentOrder() {
        let root: BSTAncestorNode? = buildTestTree(example)
        #expect(lowestCommonAncestorInBST(root, 18, 5)?.value == 10)
    }

    @Test("Returns the node itself, not a copy")
    func returnsNode() {
        let root: BSTAncestorNode? = buildTestTree(example)
        #expect(lowestCommonAncestorInBST(root, 25, 40) === root?.right)
    }

    @Test("Empty tree and a chain")
    func emptyAndChain() {
        #expect(lowestCommonAncestorInBST(nil, 1, 2) == nil)
        var chain: BSTAncestorNode?
        for value in 1...50 { chain = insert(value, into: chain) }
        #expect(lowestCommonAncestorInBST(chain, 37, 50)?.value == 37)
    }

    @Test("Agrees with the order-ignoring search on random BSTs")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 68)
        for _ in 0..<60 {
            var root: BSTAncestorNode?
            var values: [Int] = []
            for _ in 0..<generator.next(in: 1...25) {
                let value = generator.next(in: -50...50)
                if !values.contains(value) { values.append(value) }
                root = insert(value, into: root)
            }
            for first in values {
                for second in values {
                    let fast = lowestCommonAncestorInBST(root, first, second)
                    let slow = lowestCommonAncestorIgnoringOrder(root, first, second)
                    #expect(fast != nil && fast === slow)
                }
            }
        }
    }
}
