import Testing
@testable import Challenges

extension SubtreeNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> SubtreeNode { SubtreeNode(value) }
}

@Suite("Subtree of Another Tree")
struct SubtreeOfAnotherTreeTests {
    private func contains(_ tree: [Int?], _ pattern: [Int?]) -> Bool {
        isSubtree(buildTestTree(tree), buildTestTree(pattern))
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(contains([3, 4, 5, 1, 2], [4, 1, 2]))
        #expect(!contains([3, 4, 5, 1, 2, nil, nil, nil, nil, 0], [4, 1, 2]))
        #expect(contains([1, 1], [1]))
    }

    @Test("Same tree")
    func sameTree() {
        let a: SubtreeNode? = buildTestTree([1, 2, 3])
        let b: SubtreeNode? = buildTestTree([1, 2, 3])
        let mirrored: SubtreeNode? = buildTestTree([1, 3, 2])
        #expect(isSameSubtreeShape(a, b))
        #expect(!isSameSubtreeShape(a, mirrored))
        #expect(contains([1, 2, 3], [1, 2, 3]))
    }

    @Test("Same values, different shape")
    func differentShape() {
        #expect(!contains([1, 2], [1, nil, 2]))
    }

    @Test("Empty pattern and empty tree")
    func empties() {
        #expect(contains([1, 2], []))
        #expect(contains([], []))
        #expect(!contains([], [1]))
    }

    @Test("Values that share digits don't match by accident")
    func multiDigitValues() {
        #expect(!contains([12], [2]))
        #expect(!contains([1, 22], [2]))
        #expect(contains([1, 22, 2], [2]))
    }

    @Test("The match must reach down to the leaves")
    func prefixIsNotEnough() {
        #expect(!contains([1, 2, 3, 4], [2]))
        #expect(contains([1, 2, 3, 4], [2, 4]))
    }

    @Test("Agrees with the brute force on random trees")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 67)
        var found = 0
        for round in 0..<600 {
            let tree: SubtreeNode? = randomTestTree(count: round % 14, values: 1...2, using: &generator)
            let pattern: SubtreeNode? = randomTestTree(count: round % 4, values: 1...2, using: &generator)
            let fast = isSubtree(tree, pattern)
            #expect(fast == isSubtreeBruteForce(tree, pattern))
            if fast { found += 1 }
        }
        #expect(found > 50 && found < 550)
    }
}
