import Testing
@testable import Challenges

private func makeList(_ values: [Int]) -> RemoveNthListNode? {
    var head: RemoveNthListNode? = nil
    for value in values.reversed() {
        head = RemoveNthListNode(value, next: head)
    }
    return head
}

private func values(_ head: RemoveNthListNode?) -> [Int] {
    var result: [Int] = []
    var current = head
    while let node = current {
        result.append(node.value)
        current = node.next
    }
    return result
}

@Suite("Remove Nth Node From the End")
struct RemoveNthFromEndTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(values(removeNthFromEnd(makeList([10, 20, 30, 40, 50]), 2)) == [10, 20, 30, 50])
        #expect(values(removeNthFromEnd(makeList([10, 20, 30]), 3)) == [20, 30])
        #expect(values(removeNthFromEnd(makeList([7]), 1)) == [])
    }

    @Test("Removing the last node")
    func removeLast() {
        #expect(values(removeNthFromEnd(makeList([1, 2, 3]), 1)) == [1, 2])
    }

    @Test("Removing the head of a two-node list")
    func removeHeadOfTwo() {
        #expect(values(removeNthFromEnd(makeList([1, 2]), 2)) == [2])
    }

    @Test("n out of range leaves the list unchanged")
    func outOfRange() {
        #expect(values(removeNthFromEnd(makeList([1, 2, 3]), 4)) == [1, 2, 3])
        #expect(values(removeNthFromEnd(makeList([1, 2, 3]), 0)) == [1, 2, 3])
        #expect(removeNthFromEnd(nil, 1) == nil)
    }

    @Test("Every n for every length up to 12 agrees with the two-pass version")
    func agreesWithTwoPass() {
        for length in 0...12 {
            for n in 0...(length + 1) {
                let input = (0..<length).map { $0 + 1 }
                let fast = values(removeNthFromEnd(makeList(input), n))
                let slow = values(removeNthFromEndTwoPass(makeList(input), n))
                #expect(fast == slow, "length: \(length), n: \(n)")
                if n >= 1 && n <= length {
                    var expected = input
                    expected.remove(at: length - n)
                    #expect(fast == expected)
                }
            }
        }
    }
}
