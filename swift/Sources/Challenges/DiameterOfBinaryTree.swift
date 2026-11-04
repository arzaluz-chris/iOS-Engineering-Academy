/// A binary tree node for the Diameter of Binary Tree challenge.
public final class DiameterTreeNode {
    public var value: Int
    public var left: DiameterTreeNode?
    public var right: DiameterTreeNode?

    public init(_ value: Int, _ left: DiameterTreeNode? = nil, _ right: DiameterTreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Returns the number of edges on the longest path between any two nodes.
/// The path doesn't have to pass through the root. An empty tree or a single node gives 0.
///
/// One postorder pass returns each node's height (in edges, -1 for an empty subtree) and, on the
/// way, records the longest path that bends at that node: left height + right height + 2.
/// O(n) time, O(h) space on the call stack.
public func diameterOfBinaryTree(_ root: DiameterTreeNode?) -> Int {
    var longest = 0

    func height(_ node: DiameterTreeNode?) -> Int {
        guard let node else { return -1 }
        let leftHeight = height(node.left)
        let rightHeight = height(node.right)
        longest = max(longest, leftHeight + rightHeight + 2)
        return 1 + max(leftHeight, rightHeight)
    }

    _ = height(root)
    return longest
}

/// Naive solution: for every node, compute both children's heights from scratch.
/// Each node's height is recomputed once per ancestor: O(n · h) time, O(n²) on a chain.
public func diameterOfBinaryTreeBruteForce(_ root: DiameterTreeNode?) -> Int {
    func height(_ node: DiameterTreeNode?) -> Int {
        guard let node else { return -1 }
        return 1 + max(height(node.left), height(node.right))
    }
    guard let root else { return 0 }
    let throughRoot = height(root.left) + height(root.right) + 2
    return max(throughRoot,
               diameterOfBinaryTreeBruteForce(root.left),
               diameterOfBinaryTreeBruteForce(root.right))
}
