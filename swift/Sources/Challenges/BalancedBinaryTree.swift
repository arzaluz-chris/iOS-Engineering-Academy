/// A binary tree node for the Balanced Binary Tree challenge.
public final class BalancedTreeNode {
    public var value: Int
    public var left: BalancedTreeNode?
    public var right: BalancedTreeNode?

    public init(_ value: Int, _ left: BalancedTreeNode? = nil, _ right: BalancedTreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Returns `true` if, at every node, the heights of the left and right subtrees differ by at most 1.
///
/// A postorder helper returns a subtree's height, or `nil` as soon as any subtree below it is out
/// of balance, so each node is visited once and the walk stops early on the first imbalance.
/// O(n) time, O(h) space on the call stack.
public func isBalancedTree(_ root: BalancedTreeNode?) -> Bool {
    func balancedHeight(_ node: BalancedTreeNode?) -> Int? {
        guard let node else { return -1 }
        guard let leftHeight = balancedHeight(node.left),
              let rightHeight = balancedHeight(node.right),
              abs(leftHeight - rightHeight) <= 1
        else { return nil }
        return 1 + max(leftHeight, rightHeight)
    }
    return balancedHeight(root) != nil
}

/// Naive solution: at each node, compute both heights from scratch, then check the children.
/// Every node's height is recomputed once per ancestor: O(n · h) time, which is O(n log n)
/// on a balanced tree. O(h) space.
public func isBalancedTreeTopDown(_ root: BalancedTreeNode?) -> Bool {
    func height(_ node: BalancedTreeNode?) -> Int {
        guard let node else { return -1 }
        return 1 + max(height(node.left), height(node.right))
    }
    guard let root else { return true }
    return abs(height(root.left) - height(root.right)) <= 1
        && isBalancedTreeTopDown(root.left)
        && isBalancedTreeTopDown(root.right)
}
