/// A binary search tree node for the Recover Binary Search Tree challenge.
public final class RecoverBSTNode {
    public var value: Int
    public var left: RecoverBSTNode?
    public var right: RecoverBSTNode?

    public init(_ value: Int, _ left: RecoverBSTNode? = nil, _ right: RecoverBSTNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Repairs, in place, a binary search tree with distinct values in which exactly two nodes had
/// their values swapped. The shape doesn't change; only those two values trade back.
///
/// An inorder walk of a valid BST is strictly increasing. Swapping two values creates one "drop"
/// (when the two nodes are next to each other in inorder) or two. The first misplaced node is the
/// larger side of the first drop; the second is the smaller side of the last drop.
/// O(n) time, O(h) space for the explicit stack.
public func recoverBinarySearchTree(_ root: RecoverBSTNode?) {
    var stack: [RecoverBSTNode] = []
    var current = root
    var previous: RecoverBSTNode?
    var first: RecoverBSTNode?
    var second: RecoverBSTNode?

    while current != nil || !stack.isEmpty {
        while let node = current {
            stack.append(node)
            current = node.left
        }
        let node = stack.removeLast()
        if let previous, previous.value > node.value {
            if first == nil { first = previous }
            second = node
        }
        previous = node
        current = node.right
    }

    if let first, let second {
        (first.value, second.value) = (second.value, first.value)
    }
}

/// Naive solution: copy the values out in inorder, sort them, and write them back in inorder.
/// O(n log n) time, O(n) space.
public func recoverBinarySearchTreeBySorting(_ root: RecoverBSTNode?) {
    var nodes: [RecoverBSTNode] = []
    func collect(_ node: RecoverBSTNode?) {
        guard let node else { return }
        collect(node.left)
        nodes.append(node)
        collect(node.right)
    }
    collect(root)
    let sortedValues = nodes.map(\.value).sorted()
    for (node, value) in zip(nodes, sortedValues) {
        node.value = value
    }
}
