/// A binary search tree node for the Lowest Common Ancestor in a BST challenge.
public final class BSTAncestorNode {
    public var value: Int
    public var left: BSTAncestorNode?
    public var right: BSTAncestorNode?

    public init(_ value: Int, _ left: BSTAncestorNode? = nil, _ right: BSTAncestorNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Returns the deepest node that has both `first` and `second` in its subtree (a node counts as
/// being in its own subtree). Values in the tree are distinct; returns `nil` if the tree is empty.
/// The caller guarantees both values are in the tree.
///
/// Walks down from the root: while both values are smaller than the current node, the answer is in
/// the left subtree; while both are larger, it's in the right one. The first node where they split,
/// or that equals one of them, is the answer. O(h) time, O(1) extra space.
public func lowestCommonAncestorInBST(
    _ root: BSTAncestorNode?, _ first: Int, _ second: Int
) -> BSTAncestorNode? {
    var current = root
    while let node = current {
        if first < node.value && second < node.value {
            current = node.left
        } else if first > node.value && second > node.value {
            current = node.right
        } else {
            return node
        }
    }
    return nil
}

/// Naive solution: ignores the ordering and searches the whole tree, as you would in a plain binary
/// tree. Each call reports the node it found below it; the first node that hears back from both
/// sides is the answer. O(n) time, O(h) space on the call stack.
public func lowestCommonAncestorIgnoringOrder(
    _ root: BSTAncestorNode?, _ first: Int, _ second: Int
) -> BSTAncestorNode? {
    guard let root else { return nil }
    if root.value == first || root.value == second { return root }
    let fromLeft = lowestCommonAncestorIgnoringOrder(root.left, first, second)
    let fromRight = lowestCommonAncestorIgnoringOrder(root.right, first, second)
    if fromLeft != nil && fromRight != nil { return root }
    return fromLeft ?? fromRight
}
