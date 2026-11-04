/// A binary tree node for the Construct Binary Tree from Preorder and Inorder challenge.
public final class BuildTreeNode {
    public var value: Int
    public var left: BuildTreeNode?
    public var right: BuildTreeNode?

    public init(_ value: Int, _ left: BuildTreeNode? = nil, _ right: BuildTreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Rebuilds the tree whose preorder and inorder traversals are given. Values are distinct, and
/// both arrays describe the same tree. Returns `nil` for empty input.
///
/// The next unused preorder value is always the root of the subtree being built. A dictionary gives
/// that value's position in inorder in O(1), which splits the inorder range into the left and right
/// subtrees. The recursion builds the left subtree first, because that's the order preorder lists it.
/// O(n) time, O(n) space for the dictionary plus O(h) on the call stack.
public func buildTree(preorder: [Int], inorder: [Int]) -> BuildTreeNode? {
    var inorderIndex: [Int: Int] = [:]
    for (index, value) in inorder.enumerated() {
        inorderIndex[value] = index
    }
    var nextPreorder = 0

    func build(_ low: Int, _ high: Int) -> BuildTreeNode? {
        guard low <= high else { return nil }
        let rootValue = preorder[nextPreorder]
        nextPreorder += 1
        let split = inorderIndex[rootValue]!
        let node = BuildTreeNode(rootValue)
        node.left = build(low, split - 1)
        node.right = build(split + 1, high)
        return node
    }

    return build(0, inorder.count - 1)
}

/// Naive solution: find the root in inorder with a linear search and recurse on copied slices.
/// O(n²) time in the worst case (a chain), O(n²) total copying too.
public func buildTreeBySlicing(preorder: [Int], inorder: [Int]) -> BuildTreeNode? {
    guard let rootValue = preorder.first,
          let split = inorder.firstIndex(of: rootValue)
    else { return nil }
    let node = BuildTreeNode(rootValue)
    node.left = buildTreeBySlicing(
        preorder: Array(preorder[1..<(1 + split)]),
        inorder: Array(inorder[..<split]))
    node.right = buildTreeBySlicing(
        preorder: Array(preorder[(1 + split)...]),
        inorder: Array(inorder[(split + 1)...]))
    return node
}
