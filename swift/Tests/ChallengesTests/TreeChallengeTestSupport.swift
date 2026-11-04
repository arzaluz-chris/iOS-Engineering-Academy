// Shared helpers for the binary tree challenge tests. Every tree challenge has its own node class
// (they all live in one module), so the helpers work through a small protocol that each test
// file conforms its node class to.

protocol TreeChallengeTestNode: AnyObject {
    var value: Int { get set }
    var left: Self? { get set }
    var right: Self? { get set }
    static func makeTestNode(_ value: Int) -> Self
}

/// Builds a tree from a level-order list where `nil` marks a missing child,
/// the same layout as the examples in the cards: `[1, 2, 3, nil, 4]`.
func buildTestTree<Node: TreeChallengeTestNode>(_ values: [Int?]) -> Node? {
    guard let first = values.first, let rootValue = first else { return nil }
    let root = Node.makeTestNode(rootValue)
    var queue = [root]
    var head = 0
    var index = 1
    while index < values.count, head < queue.count {
        let parent = queue[head]
        head += 1
        if let leftValue = values[index] {
            let child = Node.makeTestNode(leftValue)
            parent.left = child
            queue.append(child)
        }
        index += 1
        if index < values.count, let rightValue = values[index] {
            let child = Node.makeTestNode(rightValue)
            parent.right = child
            queue.append(child)
        }
        index += 1
    }
    return root
}

/// The inverse of `buildTestTree`: level order with `nil` for missing children, trailing `nil`s removed.
func testTreeLevelOrder<Node: TreeChallengeTestNode>(_ root: Node?) -> [Int?] {
    var result: [Int?] = []
    var queue: [Node?] = [root]
    var head = 0
    while head < queue.count {
        let node = queue[head]
        head += 1
        if let node {
            result.append(node.value)
            queue.append(node.left)
            queue.append(node.right)
        } else {
            result.append(nil)
        }
    }
    while let last = result.last, last == nil { result.removeLast() }
    return result
}

/// Deep copy, so two solutions that mutate a tree can each get their own.
func copyTestTree<Node: TreeChallengeTestNode>(_ root: Node?) -> Node? {
    guard let root else { return nil }
    let copy = Node.makeTestNode(root.value)
    copy.left = copyTestTree(root.left)
    copy.right = copyTestTree(root.right)
    return copy
}

/// Small deterministic generator (an LCG) so randomized tests reproduce.
struct TreeChallengeLCG {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state >> 33
    }

    /// A value in `range`.
    mutating func next(in range: ClosedRange<Int>) -> Int {
        let width = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(next() % width)
    }
}

/// A random tree shape with `count` nodes and values drawn from `values`.
/// Each node is attached under a random existing node with a free slot, so shapes vary
/// from chains to bushy trees.
func randomTestTree<Node: TreeChallengeTestNode>(
    count: Int, values: ClosedRange<Int>, using generator: inout TreeChallengeLCG
) -> Node? {
    guard count > 0 else { return nil }
    let root = Node.makeTestNode(generator.next(in: values))
    var open: [Node] = [root]
    for _ in 1..<count {
        let parentIndex = generator.next(in: 0...(open.count - 1))
        let parent = open[parentIndex]
        let child = Node.makeTestNode(generator.next(in: values))
        let goLeft: Bool
        if parent.left == nil && parent.right == nil {
            goLeft = generator.next() % 2 == 0
        } else {
            goLeft = parent.left == nil
        }
        if goLeft { parent.left = child } else { parent.right = child }
        if parent.left != nil && parent.right != nil { open.remove(at: parentIndex) }
        open.append(child)
    }
    return root
}

/// Inorder list of values. For a binary search tree it comes out sorted.
func testTreeInorderValues<Node: TreeChallengeTestNode>(_ root: Node?) -> [Int] {
    guard let root else { return [] }
    return testTreeInorderValues(root.left) + [root.value] + testTreeInorderValues(root.right)
}
