import Testing
@testable import Challenges

@Suite("Subarray Product Less Than K")
struct SubarrayProductLessThanKTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(countLowProductStretches([4, 2, 6, 1], below: 30) == 8)
        #expect(countLowProductStretches([2, 3], below: 2) == 0)
    }

    @Test("A limit of 0 or 1 allows nothing")
    func smallLimit() {
        #expect(countLowProductStretches([1, 1, 1], below: 1) == 0)
        #expect(countLowProductStretches([1, 1, 1], below: 0) == 0)
    }

    @Test("Empty input")
    func empty() {
        #expect(countLowProductStretches([], below: 100) == 0)
    }

    @Test("Ones make every stretch count")
    func ones() {
        #expect(countLowProductStretches([1, 1, 1, 1], below: 2) == 10)
    }

    @Test("A single element at or over the limit splits the array")
    func bigElement() {
        #expect(countLowProductStretches([2, 50, 3], below: 10) == 2)
    }

    @Test("Agrees with the naive solution on random arrays")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 17)
        for _ in 0..<1_000 {
            let values = (0..<generator.next(below: 12)).map { _ in generator.next(below: 6) + 1 }
            let limit = generator.next(below: 60)
            #expect(countLowProductStretches(values, below: limit) == countLowProductStretchesBruteForce(values, below: limit))
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
