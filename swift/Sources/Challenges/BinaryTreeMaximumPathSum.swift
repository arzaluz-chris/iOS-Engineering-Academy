/// A binary tree node for the Binary Tree Maximum Path Sum challenge.
public final class MaxPathNode {
    public var value: Int
    public var left: MaxPathNode?
    public var right: MaxPathNode?

    public init(_ value: Int, _ left: MaxPathNode? = nil, _ right: MaxPathNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Returns the largest sum of values along any path in a non-empty tree. A path is a sequence of
/// at least one node where each pair of neighbors is linked by an edge, and no node repeats; it
/// doesn't have to pass through the root or end at a leaf.
///
/// Every path has one highest node where it bends. A postorder helper returns the best sum of a
/// path that starts at a node and goes straight down ("gain"); a child's gain below 0 is dropped.
/// At each node, `value + left gain + right gain` is the best path that bends there.
/// O(n) time, O(h) space on the call stack.
public func maxPathSum(_ root: MaxPathNode) -> Int {
    var best = root.value

    func gain(_ node: MaxPathNode?) -> Int {
        guard let node else { return 0 }
        let leftGain = max(0, gain(node.left))
        let rightGain = max(0, gain(node.right))
        best = max(best, node.value + leftGain + rightGain)
        return node.value + max(leftGain, rightGain)
    }

    _ = gain(root)
    return best
}

/// Naive solution: treat every node as the bend in turn and compute its children's best downward
/// sums from scratch. Each node's gain is recomputed once per ancestor: O(n · h) time, O(n²) on a
/// chain. O(h) space.
public func maxPathSumBruteForce(_ root: MaxPathNode) -> Int {
    func gain(_ node: MaxPathNode?) -> Int {
        guard let node else { return 0 }
        return node.value + max(0, gain(node.left), gain(node.right))
    }
    var best = Int.min
    var pending = [root]
    while let node = pending.popLast() {
        best = max(best, node.value + max(0, gain(node.left)) + max(0, gain(node.right)))
        if let left = node.left { pending.append(left) }
        if let right = node.right { pending.append(right) }
    }
    return best
}
