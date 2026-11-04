/// A node holding one decimal digit, for the Add Two Numbers as Linked Lists challenge.
/// Lists store the least significant digit first.
public final class DigitListNode {
    public let digit: Int
    public var next: DigitListNode?

    public init(_ digit: Int, next: DigitListNode? = nil) {
        self.digit = digit
        self.next = next
    }
}

/// Adds two non-negative numbers stored as digit lists, least significant digit first,
/// and returns their sum in the same form. An empty list counts as zero, and so does
/// the result of adding two empty lists (`nil`).
///
/// Grade-school addition: walk both lists together, add the two digits and the carry,
/// keep `sum % 10` and carry `sum / 10`. A shorter list contributes 0 once it runs out,
/// and a final carry becomes one more node. Works for numbers of any length, because it never
/// builds an Int. O(max(n, m)) time, O(max(n, m)) space for the result.
public func addDigitLists(_ first: DigitListNode?, _ second: DigitListNode?) -> DigitListNode? {
    let dummy = DigitListNode(0)
    var tail = dummy
    var a = first
    var b = second
    var carry = 0
    while a != nil || b != nil || carry > 0 {
        let sum = (a?.digit ?? 0) + (b?.digit ?? 0) + carry
        let node = DigitListNode(sum % 10)
        tail.next = node
        tail = node
        carry = sum / 10
        a = a?.next
        b = b?.next
    }
    return dummy.next
}

/// Naive version: turn each list into an Int, add, and turn the sum back into a list.
/// O(max(n, m)) time, but it overflows as soon as a number has more than 18 digits,
/// which is why it's only a reference for small inputs.
public func addDigitListsViaInt(_ first: DigitListNode?, _ second: DigitListNode?) -> DigitListNode? {
    func number(_ head: DigitListNode?) -> Int {
        var total = 0
        var place = 1
        var current = head
        while let node = current {
            total += node.digit * place
            place *= 10
            current = node.next
        }
        return total
    }
    var sum = number(first) + number(second)
    if first == nil && second == nil {
        return nil
    }
    let head = DigitListNode(sum % 10)
    var tail = head
    sum /= 10
    while sum > 0 {
        let node = DigitListNode(sum % 10)
        tail.next = node
        tail = node
        sum /= 10
    }
    return head
}
