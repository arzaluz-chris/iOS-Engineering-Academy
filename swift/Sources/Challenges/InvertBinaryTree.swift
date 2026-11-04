/// A binary tree node for the Invert Binary Tree challenge.
public final class InvertTreeNode {
    public var value: Int
    public var left: InvertTreeNode?
    public var right: InvertTreeNode?

    public init(_ value: Int, _ left: InvertTreeNode? = nil, _ right: InvertTreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Mirrors the tree in place, so every node's left and right children trade places,
/// and returns the same root.
///
/// An explicit stack holds the nodes still waiting to be swapped, so the depth of the tree
/// never touches the call stack. O(n) time; O(h) extra space for the stack, where h is the height.
public func invertTree(_ root: InvertTreeNode?) -> InvertTreeNode? {
    guard let root else { return nil }
    var pending = [root]
    while let node = pending.popLast() {
        swap(&node.left, &node.right)
        if let left = node.left { pending.append(left) }
        if let right = node.right { pending.append(right) }
    }
    return root
}

/// Naive solution: the recursive version. O(n) time, O(h) space on the call stack,
/// which can overflow on a very deep, chain-shaped tree.
public func invertTreeRecursive(_ root: InvertTreeNode?) -> InvertTreeNode? {
    guard let root else { return nil }
    let invertedLeft = invertTreeRecursive(root.left)
    root.left = invertTreeRecursive(root.right)
    root.right = invertedLeft
    return root
}
