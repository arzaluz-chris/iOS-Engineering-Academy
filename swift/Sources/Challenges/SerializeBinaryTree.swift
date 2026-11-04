/// A binary tree node for the Serialize and Deserialize Binary Tree challenge.
public final class CodecTreeNode {
    public var value: Int
    public var left: CodecTreeNode?
    public var right: CodecTreeNode?

    public init(_ value: Int, _ left: CodecTreeNode? = nil, _ right: CodecTreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Writes a binary tree as a string that `deserializeTree` can read back.
///
/// The format is preorder, comma-separated, with `#` for every empty child: the tree
/// `1(2, 3(4, -))` becomes `"1,2,#,#,3,4,#,#,#"`. Each node writes its value and then its two
/// subtrees, so the reader always knows what comes next: a `#` closes one slot, a number opens a
/// node with two new slots. Both directions use explicit stacks, so a deep tree can't overflow the
/// call stack. O(n) time and O(n) space each way.
public func serializeTree(_ root: CodecTreeNode?) -> String {
    var tokens: [String] = []
    var pending: [CodecTreeNode?] = [root]
    while let next = pending.popLast() {
        guard let node = next else {
            tokens.append("#")
            continue
        }
        tokens.append(String(node.value))
        pending.append(node.right)
        pending.append(node.left)
    }
    return tokens.joined(separator: ",")
}

/// Rebuilds the tree written by `serializeTree`. Returns `nil` for `"#"`, and also for text that
/// isn't a complete tree in this format.
public func deserializeTree(_ text: String) -> CodecTreeNode? {
    let tokens = text.split(separator: ",", omittingEmptySubsequences: false)
    guard let first = tokens.first, first != "#", let rootValue = Int(first) else { return nil }

    let root = CodecTreeNode(rootValue)
    // Nodes whose children are still being read, and how many of those children are done.
    var open: [(node: CodecTreeNode, filled: Int)] = [(root, 0)]

    for token in tokens.dropFirst() {
        guard let (parent, filled) = open.popLast() else { return nil }
        var child: CodecTreeNode?
        if token != "#" {
            guard let value = Int(token) else { return nil }
            child = CodecTreeNode(value)
        }
        if filled == 0 {
            parent.left = child
            open.append((parent, 1))
        } else {
            parent.right = child
        }
        if let child { open.append((child, 0)) }
    }
    return open.isEmpty ? root : nil
}

/// Naive solution: store each node at its position in a complete binary tree (children of slot i at
/// 2i + 1 and 2i + 2), with `#` for empty slots. Simple, but the array needs 2^h - 1 slots, so a
/// chain of 40 nodes needs about a trillion of them. Only for small trees.
public func serializeTreeByPosition(_ root: CodecTreeNode?) -> String {
    func height(_ node: CodecTreeNode?) -> Int {
        guard let node else { return 0 }
        return 1 + max(height(node.left), height(node.right))
    }
    var slots = [String](repeating: "#", count: (1 << height(root)) - 1)
    func place(_ node: CodecTreeNode?, _ slot: Int) {
        guard let node else { return }
        slots[slot] = String(node.value)
        place(node.left, 2 * slot + 1)
        place(node.right, 2 * slot + 2)
    }
    place(root, 0)
    return slots.joined(separator: ",")
}

/// Reads the format written by `serializeTreeByPosition`.
public func deserializeTreeByPosition(_ text: String) -> CodecTreeNode? {
    let slots = text.split(separator: ",").map { Int($0) }
    func build(_ slot: Int) -> CodecTreeNode? {
        guard slot < slots.count, let value = slots[slot] else { return nil }
        return CodecTreeNode(value, build(2 * slot + 1), build(2 * slot + 2))
    }
    return build(0)
}
