/// A node of a singly linked list, for the Reorder List challenge.
public final class ReorderListNode {
    public let value: Int
    public var next: ReorderListNode?

    public init(_ value: Int, next: ReorderListNode? = nil) {
        self.value = value
        self.next = next
    }
}

/// Relinks the list L0 → L1 → … → Ln into L0 → Ln → L1 → Ln-1 → L2 → …, in place.
///
/// Three steps, each a single pass: fast and slow pointers find the end of the first half;
/// the second half is cut off and reversed; then the two halves are woven together, one node
/// from each in turn. The first half is never shorter, so it supplies the last node for odd lengths.
/// O(n) time, O(1) extra space.
public func reorderList(_ head: ReorderListNode?) {
    guard let head else { return }

    var slow = head
    var fast = head
    while let step = fast.next, let secondStep = step.next, let nextSlow = slow.next {
        slow = nextSlow
        fast = secondStep
    }

    var back: ReorderListNode? = nil
    var current = slow.next
    slow.next = nil
    while let node = current {
        let next = node.next
        node.next = back
        back = node
        current = next
    }

    var front: ReorderListNode? = head
    while let frontNode = front, let backNode = back {
        let frontNext = frontNode.next
        let backNext = backNode.next
        frontNode.next = backNode
        backNode.next = frontNext
        front = frontNext
        back = backNext
    }
}

/// Naive version: put every node in an array, then relink from both ends toward the middle.
/// O(n) time, O(n) extra space.
public func reorderListBruteForce(_ head: ReorderListNode?) {
    var nodes: [ReorderListNode] = []
    var current = head
    while let node = current {
        nodes.append(node)
        current = node.next
    }
    var low = 0
    var high = nodes.count - 1
    while low < high {
        nodes[low].next = nodes[high]
        low += 1
        if low == high { break }
        nodes[high].next = nodes[low]
        high -= 1
    }
    if !nodes.isEmpty {
        nodes[low].next = nil
    }
}
