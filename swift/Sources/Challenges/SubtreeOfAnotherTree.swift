/// A binary tree node for the Subtree of Another Tree challenge.
public final class SubtreeNode {
    public var value: Int
    public var left: SubtreeNode?
    public var right: SubtreeNode?

    public init(_ value: Int, _ left: SubtreeNode? = nil, _ right: SubtreeNode? = nil) {
        self.value = value
        self.left = left
        self.right = right
    }
}

/// Returns `true` if the two trees have the same shape and the same value at every position.
/// O(min(n, m)) time, O(h) space on the call stack.
public func isSameSubtreeShape(_ first: SubtreeNode?, _ second: SubtreeNode?) -> Bool {
    switch (first, second) {
    case (nil, nil):
        return true
    case let (first?, second?):
        return first.value == second.value
            && isSameSubtreeShape(first.left, second.left)
            && isSameSubtreeShape(first.right, second.right)
    default:
        return false
    }
}

/// Returns `true` if some node of `tree`, together with everything below it, is identical to
/// `pattern`. An empty pattern counts as a subtree of any tree.
///
/// Both trees are flattened to preorder token lists where `nil` marks an empty child. A subtree's
/// tokens are one contiguous block, and a full tree's token list can't be a proper prefix of
/// another tree's, so `pattern` is a subtree exactly when its tokens appear as a block inside
/// `tree`'s. Knuth–Morris–Pratt finds the block in linear time.
/// O(n + m) time and space, for trees of n and m nodes.
public func isSubtree(_ tree: SubtreeNode?, _ pattern: SubtreeNode?) -> Bool {
    let needle = subtreePreorderTokens(pattern)
    let haystack = subtreePreorderTokens(tree)

    // failure[i]: length of the longest proper prefix of needle[0...i] that is also a suffix of it.
    var failure = [Int](repeating: 0, count: needle.count)
    var matched = 0
    for index in needle.indices.dropFirst() {
        while matched > 0 && needle[index] != needle[matched] {
            matched = failure[matched - 1]
        }
        if needle[index] == needle[matched] { matched += 1 }
        failure[index] = matched
    }

    matched = 0
    for token in haystack {
        while matched > 0 && token != needle[matched] {
            matched = failure[matched - 1]
        }
        if token == needle[matched] { matched += 1 }
        if matched == needle.count { return true }
    }
    return false
}

/// Preorder values with `nil` for every empty child, built with an explicit stack.
private func subtreePreorderTokens(_ root: SubtreeNode?) -> [Int?] {
    var tokens: [Int?] = []
    var pending: [SubtreeNode?] = [root]
    while let next = pending.popLast() {
        guard let node = next else {
            tokens.append(nil)
            continue
        }
        tokens.append(node.value)
        pending.append(node.right)
        pending.append(node.left)
    }
    return tokens
}

/// Naive solution: try `isSameSubtreeShape` at every node of `tree`.
/// O(n · m) time in the worst case, O(h) space.
public func isSubtreeBruteForce(_ tree: SubtreeNode?, _ pattern: SubtreeNode?) -> Bool {
    if isSameSubtreeShape(tree, pattern) { return true }
    guard let tree else { return false }
    return isSubtreeBruteForce(tree.left, pattern) || isSubtreeBruteForce(tree.right, pattern)
}
