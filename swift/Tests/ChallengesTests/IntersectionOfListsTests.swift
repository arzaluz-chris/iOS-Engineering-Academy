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

/// Builds `values` in front of `tail` and returns the new head.
private func makeList(_ values: [Int], then tail: IntersectionListNode? = nil) -> IntersectionListNode? {
    var head = tail
    for value in values.reversed() {
        head = IntersectionListNode(value, next: head)
    }
    return head
}

@Suite("Intersection of Two Linked Lists")
struct IntersectionOfListsTests {
    @Test("Example from the problem statement")
    func example() {
        let shared = makeList([30, 40, 50])
        let feature = makeList([7, 8], then: shared)
        let main = makeList([1, 2, 3, 4], then: shared)
        #expect(intersectionNode(feature, main) === shared)
        #expect(intersectionNode(main, feature) === shared)
    }

    @Test("No shared nodes, even with equal values")
    func noIntersection() {
        let a = makeList([1, 2, 3])
        let b = makeList([1, 2, 3])
        #expect(intersectionNode(a, b) == nil)
        #expect(intersectionNode(makeList([5]), makeList([6, 7, 8])) == nil)
    }

    @Test("An empty list")
    func emptyList() {
        #expect(intersectionNode(nil, makeList([1, 2])) == nil)
        #expect(intersectionNode(makeList([1, 2]), nil) == nil)
        #expect(intersectionNode(nil, nil) == nil)
    }

    @Test("The same list twice")
    func sameList() {
        let list = makeList([4, 5, 6])
        #expect(intersectionNode(list, list) === list)
    }

    @Test("One list is the tail of the other")
    func oneIsTail() {
        let tail = makeList([9, 10])
        let long = makeList([1, 2, 3], then: tail)
        #expect(intersectionNode(long, tail) === tail)
        #expect(intersectionNode(tail, long) === tail)
    }

    @Test("Only the last node is shared")
    func lastNodeShared() {
        let last = IntersectionListNode(99)
        #expect(intersectionNode(makeList([1], then: last), makeList([2, 3, 4], then: last)) === last)
    }

    @Test("Random shapes agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 3)
        for _ in 0..<500 {
            let shared = makeList(Array(repeating: 0, count: generator.next(below: 5)))
            let a = makeList(Array(repeating: 1, count: generator.next(below: 6)), then: shared)
            let b = makeList(Array(repeating: 1, count: generator.next(below: 6)), then: shared)
            #expect(intersectionNode(a, b) === intersectionNodeBruteForce(a, b))
            #expect(intersectionNodeBruteForce(a, b) === shared)
        }
    }
}
