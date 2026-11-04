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

/// A sorted list of non-empty ranges with a gap of at least 1 between neighbors.
private func randomSchedule(_ generator: inout SeededGenerator) -> [Range<Int>] {
    var ranges: [Range<Int>] = []
    var cursor = generator.next(below: 4)
    for _ in 0..<generator.next(below: 6) {
        let length = 1 + generator.next(below: 5)
        ranges.append(cursor..<(cursor + length))
        cursor += length + 1 + generator.next(below: 4)
    }
    return ranges
}

@Suite("Interval List Intersections")
struct IntervalListIntersectionsTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(commonFreeTime([9..<11, 13..<17], [10..<14, 16..<18]) == [10..<11, 13..<14, 16..<17])
        #expect(commonFreeTime([8..<18], [9..<10, 12..<13, 15..<16]) == [9..<10, 12..<13, 15..<16])
        #expect(commonFreeTime([9..<10], [10..<11]) == [])
    }

    @Test("An empty list")
    func emptyList() {
        #expect(commonFreeTime([], [1..<5]) == [])
        #expect(commonFreeTime([1..<5], []) == [])
    }

    @Test("Identical lists")
    func identical() {
        #expect(commonFreeTime([1..<3, 5..<8], [1..<3, 5..<8]) == [1..<3, 5..<8])
    }

    @Test("Ranges that end at the same time")
    func sameEnd() {
        #expect(commonFreeTime([1..<6, 8..<9], [3..<6, 7..<10]) == [3..<6, 8..<9])
    }

    @Test("No overlap at all")
    func disjoint() {
        #expect(commonFreeTime([1..<2, 5..<6], [3..<4, 7..<8]) == [])
    }

    @Test("Random schedules agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 42)
        for _ in 0..<500 {
            let a = randomSchedule(&generator)
            let b = randomSchedule(&generator)
            #expect(commonFreeTime(a, b) == commonFreeTimeBruteForce(a, b), "a: \(a), b: \(b)")
        }
    }
}
