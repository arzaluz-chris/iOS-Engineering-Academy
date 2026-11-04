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

@Suite("Remove Covered Intervals")
struct RemoveCoveredIntervalsTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(uncoveredRangeCount([0..<30, 10..<20, 25..<40]) == 2)
        #expect(uncoveredRangeCount([0..<10, 10..<20]) == 2)
        #expect(uncoveredRangeCount([5..<15, 5..<9, 2..<15]) == 1)
    }

    @Test("Empty list and a single range")
    func tiny() {
        #expect(uncoveredRangeCount([]) == 0)
        #expect(uncoveredRangeCount([3..<4]) == 1)
    }

    @Test("Same start: the longer range covers the shorter one")
    func sameStart() {
        #expect(uncoveredRangeCount([1..<4, 1..<8]) == 1)
    }

    @Test("Same end: the earlier start covers the later one")
    func sameEnd() {
        #expect(uncoveredRangeCount([4..<8, 1..<8]) == 1)
    }

    @Test("Partial overlaps don't count as covering")
    func partialOverlap() {
        #expect(uncoveredRangeCount([1..<5, 3..<7, 6..<9]) == 3)
    }

    @Test("Nested chain")
    func nested() {
        #expect(uncoveredRangeCount([3..<4, 2..<5, 1..<6, 0..<7]) == 1)
    }

    @Test("Random distinct ranges agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 1234)
        for _ in 0..<500 {
            var unique: Set<Range<Int>> = []
            for _ in 0..<generator.next(below: 10) {
                let start = generator.next(below: 12)
                unique.insert(start..<(start + 1 + generator.next(below: 6)))
            }
            let ranges = unique.sorted { ($0.lowerBound, $0.upperBound) < ($1.lowerBound, $1.upperBound) }
            var shuffled = ranges
            for index in shuffled.indices.reversed() {
                shuffled.swapAt(index, generator.next(below: index + 1))
            }
            #expect(uncoveredRangeCount(shuffled) == uncoveredRangeCountBruteForce(shuffled), "ranges: \(shuffled)")
        }
    }
}
