/// A node of a singly linked list of integers, for the Sort a Linked List challenge.
public final class SortListNode {
    public var value: Int
    public var next: SortListNode?

    public init(_ value: Int, next: SortListNode? = nil) {
        self.value = value
        self.next = next
    }

    /// Builds a list from an array and returns its head, or `nil` for an empty array.
    public static func list(_ values: [Int]) -> SortListNode? {
        var head: SortListNode?
        for value in values.reversed() {
            head = SortListNode(value, next: head)
        }
        return head
    }

    /// The values from `head` to the end, in order.
    public static func values(_ head: SortListNode?) -> [Int] {
        var result: [Int] = []
        var node = head
        while let current = node {
            result.append(current.value)
            node = current.next
        }
        return result
    }
}

/// Sorts a linked list in ascending order by relinking its nodes, and returns the new head.
/// Equal values keep their original order (the sort is stable).
///
/// Merge sort, which suits lists better than arrays: splitting needs no copying (find the
/// middle with slow and fast pointers and cut the link), and merging relinks existing nodes
/// with no extra buffer. O(n log n) time; O(log n) space for the recursion, and no new nodes
/// besides one dummy per merge.
public func sortLinkedList(_ head: SortListNode?) -> SortListNode? {
    guard let head, head.next != nil else { return head }

    // Find the end of the first half: `slow` stops at the first middle.
    var slow = head
    var fast = head
    while let step = fast.next?.next {
        fast = step
        slow = slow.next!
    }
    let secondHalf = slow.next
    slow.next = nil

    return sortLinkedListMerge(sortLinkedList(head), sortLinkedList(secondHalf))
}

/// Merges two sorted lists by relinking their nodes. Takes from `first` on ties, which keeps
/// the sort stable.
func sortLinkedListMerge(_ first: SortListNode?, _ second: SortListNode?) -> SortListNode? {
    let dummy = SortListNode(0)
    var tail = dummy
    var first = first
    var second = second
    while let a = first, let b = second {
        if a.value <= b.value {
            tail.next = a
            first = a.next
        } else {
            tail.next = b
            second = b.next
        }
        tail = tail.next!
    }
    tail.next = first ?? second
    return dummy.next
}

/// Naive solution: insertion sort on the list. Each node is inserted into a growing sorted list
/// by walking it from the front. O(n²) time, O(1) space, stable.
public func sortLinkedListBruteForce(_ head: SortListNode?) -> SortListNode? {
    let dummy = SortListNode(0)
    var node = head
    while let current = node {
        node = current.next
        var spot = dummy
        while let candidate = spot.next, candidate.value <= current.value {
            spot = candidate
        }
        current.next = spot.next
        spot.next = current
    }
    return dummy.next
}
