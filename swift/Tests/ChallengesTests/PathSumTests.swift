import Testing
@testable import Challenges

extension PathSumNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> PathSumNode { PathSumNode(value) }
}

@Suite("Root-to-Leaf Path Sum")
struct PathSumTests {
    private func check(_ values: [Int?], _ target: Int) -> Bool {
        hasPathSum(buildTestTree(values), target)
    }

    @Test("Examples from the problem statement")
    func examples() {
        let trail: [Int?] = [5, 3, 8, 2, nil, 4, 1]
        #expect(check(trail, 10))
        #expect(check(trail, 17))
        #expect(check(trail, 14))
        #expect(!check(trail, 8))
        #expect(!check([], 0))
    }

    @Test("An empty tree has no path, even for target 0")
    func emptyTree() {
        #expect(!check([], 0))
    }

    @Test("A node with one child isn't a leaf")
    func oneChildIsNotALeaf() {
        #expect(!check([1, 2], 1))
        #expect(check([1, 2], 3))
    }

    @Test("A single node")
    func singleNode() {
        #expect(check([7], 7))
        #expect(!check([7], 0))
    }

    @Test("Negative values mean you can't stop early")
    func negatives() {
        #expect(check([-2, nil, -3], -5))
        #expect(check([1, 5, nil, -6], 0))
        #expect(check([10, -4, nil, -6], 0))
    }

    @Test("Agrees with the path-collecting version on random trees")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 64)
        for size in 0..<80 {
            let root: PathSumNode? = randomTestTree(count: size, values: -5...5, using: &generator)
            for target in -12...12 {
                #expect(hasPathSum(root, target) == hasPathSumByCollectingPaths(root, target))
            }
        }
    }
}
