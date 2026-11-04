import Testing
@testable import Challenges

@Suite("Merge Sorted Arrays in Place")
struct MergeSortedInPlaceTests {
    private func merged(_ first: [Int], _ second: [Int]) -> [Int] {
        var buffer = first + Array(repeating: 0, count: second.count)
        mergeIntoFirst(&buffer, count: first.count, second)
        return buffer
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(merged([2, 5, 9], [1, 5, 6, 12]) == [1, 2, 5, 5, 6, 9, 12])
        #expect(merged([4, 8], []) == [4, 8])
        #expect(merged([], [3, 7]) == [3, 7])
    }

    @Test("Both empty")
    func bothEmpty() {
        #expect(merged([], []) == [])
    }

    @Test("Every value of second goes before every value of first")
    func secondFirst() {
        #expect(merged([10, 20], [1, 2, 3]) == [1, 2, 3, 10, 20])
    }

    @Test("Every value of second goes after every value of first")
    func secondLast() {
        #expect(merged([1, 2], [10, 20, 30]) == [1, 2, 10, 20, 30])
    }

    @Test("Duplicates and negatives")
    func duplicates() {
        #expect(merged([-3, 0, 0], [-3, 0]) == [-3, -3, 0, 0, 0])
    }

    @Test("Agrees with copying and sorting on random arrays")
    func agreesWithSorting() {
        var generator = SeededGenerator(seed: 23)
        for _ in 0..<1_000 {
            let first = (0..<generator.next(below: 8)).map { _ in generator.next(below: 11) - 5 }.sorted()
            let second = (0..<generator.next(below: 8)).map { _ in generator.next(below: 11) - 5 }.sorted()
            var slow = first + Array(repeating: 0, count: second.count)
            mergeIntoFirstBySorting(&slow, count: first.count, second)
            #expect(merged(first, second) == slow)
        }
    }
}

/// Small deterministic generator (a linear congruential generator) so failures reproduce.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// A value in `0..<bound`.
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
