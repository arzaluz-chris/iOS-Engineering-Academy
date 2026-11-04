/// A node of a singly linked list, for the Remove Nth Node From the End challenge.
public final class RemoveNthListNode {
    public let value: Int
    public var next: RemoveNthListNode?

    public init(_ value: Int, next: RemoveNthListNode? = nil) {
        self.value = value
        self.next = next
    }
}

/// Removes the `n`-th node counting from the end (n = 1 is the last node) and returns the new head.
/// Returns the list unchanged if `n` is less than 1 or greater than its length.
///
/// One pass with two pointers and a dummy head. `lead` first moves n nodes ahead of `trail`;
/// then both move together until `lead` is on the last node, which leaves `trail` just before
/// the node to remove. The dummy gives the head a predecessor, so removing the head isn't a
/// special case. O(L) time for a list of length L, O(1) extra space.
public func removeNthFromEnd(_ head: RemoveNthListNode?, _ n: Int) -> RemoveNthListNode? {
    guard n >= 1 else { return head }
    let dummy = RemoveNthListNode(0, next: head)
    var lead = dummy
    for _ in 0..<n {
        guard let next = lead.next else { return head }
        lead = next
    }
    var trail = dummy
    while let next = lead.next, let trailNext = trail.next {
        lead = next
        trail = trailNext
    }
    trail.next = trail.next?.next
    return dummy.next
}

/// Naive version: one pass to count the nodes, a second to stop before the one to remove.
/// O(L) time and O(1) space too, but it walks the list twice.
public func removeNthFromEndTwoPass(_ head: RemoveNthListNode?, _ n: Int) -> RemoveNthListNode? {
    var length = 0
    var current = head
    while let node = current {
        length += 1
        current = node.next
    }
    guard n >= 1, n <= length else { return head }
    if n == length {
        return head?.next
    }
    var previous = head
    for _ in 0..<(length - n - 1) {
        previous = previous?.next
    }
    previous?.next = previous?.next?.next
    return head
}
