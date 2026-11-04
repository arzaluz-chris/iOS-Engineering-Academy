/// A binary tree node for the Root-to-Leaf Path Sum challenge.
public final class PathSumNode {
    public var value: Int
    public var left: PathSumNode?
    public var right: PathSumNode?

    public init(_ value: Int, _ left: PathSumNode? = nil, _ right: PathSumNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Returns `true` if some path from the root down to a leaf has values that add up to `target`.
/// A leaf is a node with no children; an empty tree has no paths.
///
/// Each call subtracts its node's value from what's left to reach and passes the rest down,
/// so no path is ever stored. O(n) time, O(h) space on the call stack, where h is the height.
public func hasPathSum(_ root: PathSumNode?, _ target: Int) -> Bool {
    guard let root else { return false }
    let remaining = target - root.value
    if root.left == nil && root.right == nil {
        return remaining == 0
    }
    return hasPathSum(root.left, remaining) || hasPathSum(root.right, remaining)
}

/// Naive solution: collect every root-to-leaf path as an array, then sum each one.
/// O(n · h) time and space, because each of up to n/2 leaves copies a path of up to h values.
public func hasPathSumByCollectingPaths(_ root: PathSumNode?, _ target: Int) -> Bool {
    var paths: [[Int]] = []
    func collect(_ node: PathSumNode?, _ path: [Int]) {
        guard let node else { return }
        let extended = path + [node.value]
        if node.left == nil && node.right == nil {
            paths.append(extended)
        }
        collect(node.left, extended)
        collect(node.right, extended)
    }
    collect(root, [])
    return paths.contains { $0.reduce(0, +) == target }
}
