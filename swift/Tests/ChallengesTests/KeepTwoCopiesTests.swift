import Testing
@testable import Challenges

@Suite("Keep At Most Two Copies")
struct KeepTwoCopiesTests {
    private func kept(_ input: [Int]) -> [Int] {
        var values = input
        keepAtMostTwoCopies(&values)
        return values
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(kept([1, 1, 1, 2, 2, 3]) == [1, 1, 2, 2, 3])
        #expect(kept([0, 0, 1, 1, 1, 1, 2, 3, 3]) == [0, 0, 1, 1, 2, 3, 3])
    }

    @Test("Empty, one and two elements")
    func tiny() {
        #expect(kept([]) == [])
        #expect(kept([4]) == [4])
        #expect(kept([4, 4]) == [4, 4])
    }

    @Test("Every value the same")
    func allSame() {
        #expect(kept([9, 9, 9, 9, 9]) == [9, 9])
    }

    @Test("Nothing to remove")
    func nothingToRemove() {
        #expect(kept([-2, -2, 0, 5, 5, 8]) == [-2, -2, 0, 5, 5, 8])
    }

    @Test("Agrees with the naive solution on random sorted arrays")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 11)
        for _ in 0..<1_000 {
            let input = (0..<generator.next(below: 12)).map { _ in generator.next(below: 5) }.sorted()
            var slow = input
            keepAtMostTwoCopiesBruteForce(&slow)
            #expect(kept(input) == slow)
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
