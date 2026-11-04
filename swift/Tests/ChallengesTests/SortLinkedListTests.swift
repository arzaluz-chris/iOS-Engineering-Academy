import Testing
@testable import Challenges

@Suite("Sort a Linked List")
struct SortLinkedListTests {
    private func sortedValues(_ values: [Int]) -> [Int] {
        SortListNode.values(sortLinkedList(SortListNode.list(values)))
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(sortedValues([42, 7, 19, 3]) == [3, 7, 19, 42])
        #expect(sortedValues([5, -1, 5, 0]) == [-1, 0, 5, 5])
    }

    @Test("Empty list and single node")
    func tiny() {
        #expect(sortLinkedList(nil) == nil)
        #expect(sortedValues([8]) == [8])
    }

    @Test("Two nodes in either order")
    func twoNodes() {
        #expect(sortedValues([1, 2]) == [1, 2])
        #expect(sortedValues([2, 1]) == [1, 2])
    }

    @Test("Already sorted, reversed, and all equal")
    func orderedInputs() {
        #expect(sortedValues(Array(1...9)) == Array(1...9))
        #expect(sortedValues(Array((1...9).reversed())) == Array(1...9))
        #expect(sortedValues([4, 4, 4, 4]) == [4, 4, 4, 4])
    }

    @Test("Relinks the original nodes instead of creating new ones")
    func reusesNodes() {
        let head = SortListNode.list([3, 1, 2])!
        let original = Set([ObjectIdentifier(head), ObjectIdentifier(head.next!), ObjectIdentifier(head.next!.next!)])
        var node = sortLinkedList(head)
        var seen = Set<ObjectIdentifier>()
        while let current = node {
            seen.insert(ObjectIdentifier(current))
            node = current.next
        }
        #expect(seen == original)
    }

    @Test("Stable: equal values keep their original order")
    func stable() {
        let head = SortListNode.list([2, 1, 2, 1])!
        let firstTwo = head
        let secondTwo = head.next!.next!
        let sorted = sortLinkedList(head)
        let thirdNode = sorted?.next?.next
        #expect(thirdNode === firstTwo)
        #expect(thirdNode?.next === secondTwo)
    }

    @Test("A long list doesn't overflow the stack")
    func longList() {
        var random = LCG(state: 61)
        let values = (0..<50_000).map { _ in random.next(-1_000_000...1_000_000) }
        #expect(sortedValues(values) == values.sorted())
    }

    @Test("Agrees with insertion sort on random lists")
    func agreesWithBruteForce() {
        var random = LCG(state: 62)
        for _ in 0..<300 {
            let values = (0..<random.next(0...30)).map { _ in random.next(-9...9) }
            let fast = sortedValues(values)
            let slow = SortListNode.values(sortLinkedListBruteForce(SortListNode.list(values)))
            #expect(fast == slow)
            #expect(fast == values.sorted())
        }
    }
}

/// Small deterministic generator so failures reproduce.
private struct LCG {
    var state: UInt64
    mutating func next(_ range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return range.lowerBound + Int((state >> 33) % UInt64(range.count))
    }
}
