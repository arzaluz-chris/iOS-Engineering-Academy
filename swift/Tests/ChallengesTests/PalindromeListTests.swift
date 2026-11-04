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

private func makeList(_ values: [Int]) -> PalindromeListNode? {
    var head: PalindromeListNode? = nil
    for value in values.reversed() {
        head = PalindromeListNode(value, next: head)
    }
    return head
}

private func nodes(_ head: PalindromeListNode?) -> [PalindromeListNode] {
    var result: [PalindromeListNode] = []
    var current = head
    while let node = current {
        result.append(node)
        current = node.next
    }
    return result
}

@Suite("Palindrome Linked List")
struct PalindromeListTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(isPalindromeList(makeList([1, 2, 3, 2, 1])))
        #expect(isPalindromeList(makeList([4, 7, 7, 4])))
        #expect(!isPalindromeList(makeList([1, 2, 3, 1])))
    }

    @Test("Empty list and a single node")
    func tiny() {
        #expect(isPalindromeList(nil))
        #expect(isPalindromeList(makeList([5])))
    }

    @Test("Two nodes")
    func twoNodes() {
        #expect(isPalindromeList(makeList([3, 3])))
        #expect(!isPalindromeList(makeList([3, 4])))
    }

    @Test("Mismatch only in the middle pair")
    func middleMismatch() {
        #expect(!isPalindromeList(makeList([1, 2, 3, 4, 2, 1])))
    }

    @Test("The list is restored afterward, node for node", arguments: [
        [1, 2, 3, 2, 1], [1, 2, 3, 1], [6, 6], [1, 2, 3, 4, 5, 6],
    ])
    func restoresList(input: [Int]) {
        let head = makeList(input)
        let before = nodes(head)
        _ = isPalindromeList(head)
        let after = nodes(head)
        #expect(after.count == before.count)
        #expect(zip(before, after).allSatisfy { $0 === $1 })
        #expect(after.map(\.value) == input)
    }

    @Test("Random lists agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 21)
        for _ in 0..<500 {
            let half = (0..<generator.next(below: 6)).map { _ in generator.next(below: 3) }
            var input = half + (generator.next(below: 2) == 0 ? [] : [generator.next(below: 3)]) + half.reversed()
            if generator.next(below: 3) == 0 && !input.isEmpty {
                input[generator.next(below: input.count)] = generator.next(below: 3)
            }
            #expect(isPalindromeList(makeList(input)) == isPalindromeListBruteForce(makeList(input)), "input: \(input)")
        }
    }
}
