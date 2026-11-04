/// A node with a `next` link and an extra `random` link to any node of the same list, or `nil`.
///
/// `random` is `weak`: it can point backward or at the node itself, and a strong reference
/// there would create a reference cycle that ARC never frees. The `next` chain owns the nodes,
/// so a weak `random` stays valid as long as someone holds the head.
public final class RandomListNode {
    public let value: Int
    public var next: RandomListNode?
    public weak var random: RandomListNode?

    public init(_ value: Int, next: RandomListNode? = nil) {
        self.value = value
        self.next = next
    }
}

/// Returns a deep copy of the list: new nodes with the same values, whose `next` and `random`
/// links point at the corresponding new nodes. The original list isn't modified.
///
/// Two passes with a dictionary from each original node's identity to its copy. The first pass
/// creates the copies; the second wires `next` and `random` by looking up the copies of the nodes
/// the original links point to. O(n) time on average, O(n) extra space for the dictionary.
public func copyRandomList(_ head: RandomListNode?) -> RandomListNode? {
    var copyOf: [ObjectIdentifier: RandomListNode] = [:]
    var current = head
    while let node = current {
        copyOf[ObjectIdentifier(node)] = RandomListNode(node.value)
        current = node.next
    }

    current = head
    while let node = current {
        let copy = copyOf[ObjectIdentifier(node)]
        copy?.next = node.next.flatMap { copyOf[ObjectIdentifier($0)] }
        copy?.random = node.random.flatMap { copyOf[ObjectIdentifier($0)] }
        current = node.next
    }
    return head.flatMap { copyOf[ObjectIdentifier($0)] }
}

/// The O(1) extra space version: weave each copy right after its original (A → A' → B → B' …),
/// so the copy of any node X is `X.next`. Then set every copy's `random` to `original.random?.next`,
/// and finally unweave the two lists, restoring the original. O(n) time, O(1) extra space.
public func copyRandomListInterleaved(_ head: RandomListNode?) -> RandomListNode? {
    var current = head
    while let node = current {
        let copy = RandomListNode(node.value, next: node.next)
        node.next = copy
        current = copy.next
    }

    current = head
    while let node = current, let copy = node.next {
        copy.random = node.random?.next
        current = copy.next
    }

    let copyHead = head?.next
    current = head
    while let node = current, let copy = node.next {
        node.next = copy.next
        copy.next = copy.next?.next
        current = node.next
    }
    return copyHead
}

/// Naive version: copy the `next` chain into an array of new nodes, then, for each original
/// node, find the position of its `random` target by walking the list from the head.
/// O(n²) time, O(n) space.
public func copyRandomListBruteForce(_ head: RandomListNode?) -> RandomListNode? {
    var originals: [RandomListNode] = []
    var current = head
    while let node = current {
        originals.append(node)
        current = node.next
    }
    let copies = originals.map { RandomListNode($0.value) }
    for index in copies.indices.dropLast() {
        copies[index].next = copies[index + 1]
    }
    for (index, original) in originals.enumerated() {
        guard let target = original.random else { continue }
        var position = 0
        var walker = head
        while let node = walker, node !== target {
            position += 1
            walker = node.next
        }
        copies[index].random = copies[position]
    }
    return copies.first
}
