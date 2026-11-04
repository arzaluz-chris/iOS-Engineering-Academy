import Testing
@testable import Challenges

private func makeList(_ values: [Int]) -> ReorderListNode? {
    var head: ReorderListNode? = nil
    for value in values.reversed() {
        head = ReorderListNode(value, next: head)
    }
    return head
}

private func nodes(_ head: ReorderListNode?) -> [ReorderListNode] {
    var result: [ReorderListNode] = []
    var current = head
    while let node = current, result.count <= 1_000 {
        result.append(node)
        current = node.next
    }
    return result
}

@Suite("Reorder List")
struct ReorderListTests {
    @Test("Examples from the problem statement")
    func examples() {
        let even = makeList([1, 2, 3, 4, 5, 6])
        reorderList(even)
        #expect(nodes(even).map(\.value) == [1, 6, 2, 5, 3, 4])

        let odd = makeList([10, 20, 30, 40, 50])
        reorderList(odd)
        #expect(nodes(odd).map(\.value) == [10, 50, 20, 40, 30])
    }

    @Test("Empty list, one node and two nodes are unchanged")
    func tiny() {
        reorderList(nil)
        let one = makeList([1])
        reorderList(one)
        #expect(nodes(one).map(\.value) == [1])
        let two = makeList([1, 2])
        reorderList(two)
        #expect(nodes(two).map(\.value) == [1, 2])
    }

    @Test("Three nodes")
    func three() {
        let list = makeList([1, 2, 3])
        reorderList(list)
        #expect(nodes(list).map(\.value) == [1, 3, 2])
    }

    @Test("Same order as the naive version, for every length up to 30", arguments: 0...30)
    func agreesWithBruteForce(length: Int) {
        let input = Array(0..<length)
        let fast = makeList(input)
        let slow = makeList(input)
        reorderList(fast)
        reorderListBruteForce(slow)
        #expect(nodes(fast).map(\.value) == nodes(slow).map(\.value))
    }

    @Test("The nodes are relinked, not copied, and the list ends with nil", arguments: [1, 2, 5, 8])
    func relinksSameNodes(length: Int) {
        let head = makeList(Array(0..<length))
        let before = Set(nodes(head).map(ObjectIdentifier.init))
        reorderList(head)
        let after = nodes(head)
        #expect(after.count == length)
        #expect(Set(after.map(ObjectIdentifier.init)) == before)
        #expect(after.last?.next == nil)
    }
}
