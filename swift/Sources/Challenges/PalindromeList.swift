/// A node of a singly linked list, for the Palindrome Linked List challenge.
public final class PalindromeListNode {
    public let value: Int
    public var next: PalindromeListNode?

    public init(_ value: Int, next: PalindromeListNode? = nil) {
        self.value = value
        self.next = next
    }
}

/// Returns whether the values in the list read the same forward and backward.
/// The list is temporarily changed and then restored, so the caller sees it unchanged.
///
/// Fast and slow pointers find the end of the first half; the second half is reversed in place
/// and compared with the first; then it's reversed back. O(n) time, O(1) extra space.
public func isPalindromeList(_ head: PalindromeListNode?) -> Bool {
    guard let head else { return true }

    // End of the first half: the middle node for odd lengths, the first middle for even ones.
    var firstHalfEnd = head
    var fast = head
    while let step = fast.next, let secondStep = step.next, let nextSlow = firstHalfEnd.next {
        firstHalfEnd = nextSlow
        fast = secondStep
    }

    let secondHalf = reversePalindromeHalf(firstHalfEnd.next)
    var left: PalindromeListNode? = head
    var right = secondHalf
    var matches = true
    while let rightNode = right, let leftNode = left {
        if leftNode.value != rightNode.value {
            matches = false
            break
        }
        left = leftNode.next
        right = rightNode.next
    }

    firstHalfEnd.next = reversePalindromeHalf(secondHalf)
    return matches
}

/// Reverses a list in place and returns its new head. O(n) time, O(1) space.
func reversePalindromeHalf(_ head: PalindromeListNode?) -> PalindromeListNode? {
    var previous: PalindromeListNode? = nil
    var current = head
    while let node = current {
        let next = node.next
        node.next = previous
        previous = node
        current = next
    }
    return previous
}

/// Naive version: copy the values into an array and compare it with its reverse.
/// O(n) time, O(n) extra space.
public func isPalindromeListBruteForce(_ head: PalindromeListNode?) -> Bool {
    var values: [Int] = []
    var current = head
    while let node = current {
        values.append(node.value)
        current = node.next
    }
    return values == values.reversed()
}
