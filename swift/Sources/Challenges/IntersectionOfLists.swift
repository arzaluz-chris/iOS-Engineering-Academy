/// A node of a singly linked list, for the Intersection of Two Linked Lists challenge.
/// Think of each node as a commit and `next` as its parent.
public final class IntersectionListNode {
    public let value: Int
    public var next: IntersectionListNode?

    public init(_ value: Int, next: IntersectionListNode? = nil) {
        self.value = value
        self.next = next
    }
}

/// Returns the first node shared by two lists (compared by identity, not by value),
/// or `nil` if they never meet.
///
/// Two pointers walk the lists; when one runs off the end, it continues from the head of the
/// other list. Both then travel a + c + b nodes before meeting at the shared node, where a and b
/// are the lengths of the unshared parts and c the length of the shared tail. If there's no shared
/// tail, both reach `nil` together after a + b steps. O(a + b + c) time, O(1) space.
public func intersectionNode(_ first: IntersectionListNode?, _ second: IntersectionListNode?) -> IntersectionListNode? {
    var a = first
    var b = second
    while a !== b {
        a = a == nil ? second : a?.next
        b = b == nil ? first : b?.next
    }
    return a
}

/// Naive version: for each node of the first list, walk the whole second list looking for it.
/// O(n · m) time, O(1) space.
public func intersectionNodeBruteForce(_ first: IntersectionListNode?, _ second: IntersectionListNode?) -> IntersectionListNode? {
    var a = first
    while let nodeA = a {
        var b = second
        while let nodeB = b {
            if nodeA === nodeB {
                return nodeA
            }
            b = nodeB.next
        }
        a = nodeA.next
    }
    return nil
}
