/// A node of a singly linked list of integers, for the Remove Duplicates from a Sorted List challenge.
public final class DedupListNode {
    public var value: Int
    public var next: DedupListNode?

    public init(_ value: Int, next: DedupListNode? = nil) {
        self.value = value
        self.next = next
    }
}

/// Removes repeated values from a list sorted in non-decreasing order, keeping the first node
/// of each run, and returns the head (which never changes).
///
/// Equal values sit next to each other, so each node only has to be compared with the one after it:
/// while the next node repeats the current value, the current node skips it.
/// O(n) time, O(1) extra space. The skipped nodes are freed by ARC.
@discardableResult
public func removeDuplicateNodes(_ head: DedupListNode?) -> DedupListNode? {
    var current = head
    while let node = current {
        while let following = node.next, following.value == node.value {
            node.next = following.next
        }
        current = node.next
    }
    return head
}

/// Naive version: copy the values into an array, drop repeats, and build a new list.
/// O(n) time but O(n) extra space, and it allocates new nodes instead of relinking.
public func removeDuplicateNodesBruteForce(_ head: DedupListNode?) -> DedupListNode? {
    var values: [Int] = []
    var current = head
    while let node = current {
        if values.last != node.value {
            values.append(node.value)
        }
        current = node.next
    }
    var newHead: DedupListNode? = nil
    for value in values.reversed() {
        newHead = DedupListNode(value, next: newHead)
    }
    return newHead
}
