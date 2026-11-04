import Testing
@testable import Challenges

extension CodecTreeNode: TreeChallengeTestNode {
    static func makeTestNode(_ value: Int) -> CodecTreeNode { CodecTreeNode(value) }
}

@Suite("Serialize and Deserialize Binary Tree")
struct SerializeBinaryTreeTests {
    @Test("Examples from the problem statement")
    func examples() {
        let root: CodecTreeNode? = buildTestTree([1, 2, 3, nil, nil, 4])
        #expect(serializeTree(root) == "1,2,#,#,3,4,#,#,#")
        #expect(serializeTree(nil) == "#")
        #expect(testTreeLevelOrder(deserializeTree("1,2,#,#,3,4,#,#,#")) == [1, 2, 3, nil, nil, 4])
    }

    @Test("Empty tree and a single node round-trip")
    func tiny() {
        #expect(deserializeTree("#") == nil)
        #expect(testTreeLevelOrder(deserializeTree(serializeTree(CodecTreeNode(7)))) == [7])
    }

    @Test("Negative and multi-digit values")
    func negatives() {
        let root: CodecTreeNode? = buildTestTree([-12, 300, nil, -4])
        let text = serializeTree(root)
        #expect(text == "-12,300,-4,#,#,#,#")
        #expect(testTreeLevelOrder(deserializeTree(text)) == [-12, 300, nil, -4])
    }

    @Test("Malformed input gives nil instead of crashing")
    func malformed() {
        #expect(deserializeTree("") == nil)
        #expect(deserializeTree("1,#") == nil)
        #expect(deserializeTree("1,#,#,#") == nil)
        #expect(deserializeTree("1,x,#") == nil)
        #expect(deserializeTree("1,,#") == nil)
    }

    @Test("A deep chain round-trips without recursion")
    func deepChain() {
        let root = CodecTreeNode(0)
        var tail = root
        for value in 1..<50_000 {
            let next = CodecTreeNode(value)
            tail.right = next
            tail = next
        }
        let decoded = deserializeTree(serializeTree(root))
        var count = 0
        var cursor = decoded
        while let node = cursor {
            #expect(node.value == count)
            count += 1
            cursor = node.right
        }
        #expect(count == 50_000)
        // Cut both chains so releasing them doesn't recurse 50,000 levels through deinit.
        for start in [root, decoded] {
            var link = start
            while let node = link {
                link = node.right
                node.right = nil
            }
        }
    }

    @Test("Random trees round-trip with both formats")
    func roundTrip() {
        var generator = TreeChallengeLCG(seed: 73)
        for size in 0..<60 {
            let root: CodecTreeNode? = randomTestTree(count: size, values: -1_000...1_000, using: &generator)
            let expected = testTreeLevelOrder(root)
            #expect(testTreeLevelOrder(deserializeTree(serializeTree(root))) == expected)
            if size < 12 {
                let naive = serializeTreeByPosition(root)
                #expect(testTreeLevelOrder(deserializeTreeByPosition(naive)) == expected)
            }
        }
    }
}
