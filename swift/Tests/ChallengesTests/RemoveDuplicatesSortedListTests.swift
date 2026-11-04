import Testing
@testable import Challenges

/// Deterministic pseudo-random numbers (a 64-bit LCG), so a failing case reproduces.
private struct SeededGenerator {
    var state: UInt64
    mutating func next(below bound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
}

private func makeList(_ values: [Int]) -> DedupListNode? {
    var head: DedupListNode? = nil
    for value in values.reversed() {
        head = DedupListNode(value, next: head)
    }
    return head
}

private func values(_ head: DedupListNode?) -> [Int] {
    var result: [Int] = []
    var current = head
    while let node = current {
        result.append(node.value)
        current = node.next
    }
    return result
}

@Suite("Remove Duplicates from a Sorted List")
struct RemoveDuplicatesSortedListTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(values(removeDuplicateNodes(makeList([1, 1, 2, 3, 3, 3, 5]))) == [1, 2, 3, 5])
        #expect(values(removeDuplicateNodes(makeList([4, 4, 4]))) == [4])
        #expect(values(removeDuplicateNodes(makeList([2, 6, 9]))) == [2, 6, 9])
    }

    @Test("Empty list and a single node")
    func tiny() {
        #expect(removeDuplicateNodes(nil) == nil)
        #expect(values(removeDuplicateNodes(makeList([8]))) == [8])
    }

    @Test("A run of duplicates at the end")
    func runAtTail() {
        #expect(values(removeDuplicateNodes(makeList([1, 2, 2, 2]))) == [1, 2])
    }

    @Test("Negative values")
    func negatives() {
        #expect(values(removeDuplicateNodes(makeList([-3, -3, 0, 0, 7]))) == [-3, 0, 7])
    }

    @Test("The list is relinked in place: same head, same surviving nodes")
    func inPlace() {
        let head = makeList([1, 1, 2])
        let nodeWithTwo = head?.next?.next
        let result = removeDuplicateNodes(head)
        #expect(result === head)
        #expect(result?.next === nodeWithTwo)
    }

    @Test("Random sorted lists agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 11)
        for _ in 0..<500 {
            let count = generator.next(below: 15)
            let input = (0..<count).map { _ in generator.next(below: 6) }.sorted()
            let expected = values(removeDuplicateNodesBruteForce(makeList(input)))
            #expect(values(removeDuplicateNodes(makeList(input))) == expected, "input: \(input)")
        }
    }
}
