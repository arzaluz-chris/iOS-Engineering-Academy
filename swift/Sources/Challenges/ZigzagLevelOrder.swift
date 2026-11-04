/// A binary tree node for the Zigzag Level Order challenge.
public final class ZigzagTreeNode {
    public var value: Int
    public var left: ZigzagTreeNode?
    public var right: ZigzagTreeNode?

    public init(_ value: Int, _ left: ZigzagTreeNode? = nil, _ right: ZigzagTreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Returns the values level by level, reading the first level left to right, the second right to
/// left, and alternating from there.
///
/// A breadth-first walk processes one whole level per iteration of the outer loop. Children are
/// always queued left to right; only the finished level's values are reversed on odd levels.
/// O(n) time (each level is reversed at most once), O(w) space for the queue, where w is the
/// widest level, plus the output.
public func zigzagLevelOrder(_ root: ZigzagTreeNode?) -> [[Int]] {
    guard let root else { return [] }
    var result: [[Int]] = []
    var level = [root]
    while !level.isEmpty {
        var values: [Int] = []
        var nextLevel: [ZigzagTreeNode] = []
        for node in level {
            values.append(node.value)
            if let left = node.left { nextLevel.append(left) }
            if let right = node.right { nextLevel.append(right) }
        }
        result.append(result.count.isMultiple(of: 2) ? values : values.reversed())
        level = nextLevel
    }
    return result
}

/// Naive solution: find the height, then walk the whole tree once per level to collect the nodes
/// at that depth. O(n · h) time, O(h) space on the call stack plus the output.
public func zigzagLevelOrderByDepth(_ root: ZigzagTreeNode?) -> [[Int]] {
    func height(_ node: ZigzagTreeNode?) -> Int {
        guard let node else { return 0 }
        return 1 + max(height(node.left), height(node.right))
    }
    func collect(_ node: ZigzagTreeNode?, depth: Int, target: Int, into values: inout [Int]) {
        guard let node else { return }
        if depth == target {
            values.append(node.value)
            return
        }
        collect(node.left, depth: depth + 1, target: target, into: &values)
        collect(node.right, depth: depth + 1, target: target, into: &values)
    }
    var result: [[Int]] = []
    for depth in 0..<height(root) {
        var values: [Int] = []
        collect(root, depth: 0, target: depth, into: &values)
        result.append(depth.isMultiple(of: 2) ? values : values.reversed())
    }
    return result
}
