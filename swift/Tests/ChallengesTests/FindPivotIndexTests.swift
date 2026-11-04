import Testing
@testable import Challenges

@Suite("Find Pivot Index")
struct FindPivotIndexTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(balanceIndex([2, 7, 1, 3, 6]) == 2)
        #expect(balanceIndex([1, 2, 3]) == nil)
        #expect(balanceIndex([5, -3, 3]) == 0)
    }

    @Test("Empty and one-element lists")
    func tiny() {
        #expect(balanceIndex([]) == nil)
        #expect(balanceIndex([42]) == 0)
    }

    @Test("The last index")
    func lastIndex() {
        #expect(balanceIndex([4, -4, 9]) == 2)
    }

    @Test("Several balance points return the first")
    func first() {
        #expect(balanceIndex([0, 0, 0]) == 0)
        #expect(balanceIndex([1, -1, 0, 1, -1]) == 2)
    }

    @Test("Agrees with the naive solution on random arrays")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 22)
        for _ in 0..<2_000 {
            let values = (0..<generator.next(below: 9)).map { _ in generator.next(below: 7) - 3 }
            #expect(balanceIndex(values) == balanceIndexBruteForce(values))
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
