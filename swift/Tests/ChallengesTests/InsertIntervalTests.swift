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

@Suite("Insert Interval")
struct InsertIntervalTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(insertRange([0..<100, 200..<300, 500..<600], 250..<520) == [0..<100, 200..<600])
        #expect(insertRange([0..<100, 500..<600], 300..<400) == [0..<100, 300..<400, 500..<600])
        #expect(insertRange([0..<100, 200..<300], 100..<200) == [0..<300])
    }

    @Test("Empty list")
    func emptyList() {
        #expect(insertRange([], 5..<9) == [5..<9])
    }

    @Test("New range before everything and after everything")
    func ends() {
        #expect(insertRange([10..<20, 30..<40], 1..<5) == [1..<5, 10..<20, 30..<40])
        #expect(insertRange([10..<20, 30..<40], 50..<60) == [10..<20, 30..<40, 50..<60])
    }

    @Test("New range covers everything")
    func coversAll() {
        #expect(insertRange([10..<20, 30..<40, 45..<50], 0..<100) == [0..<100])
    }

    @Test("New range inside an existing one")
    func inside() {
        #expect(insertRange([10..<50], 20..<30) == [10..<50])
    }

    @Test("Touching on either side merges")
    func touching() {
        #expect(insertRange([10..<20], 20..<25) == [10..<25])
        #expect(insertRange([10..<20], 5..<10) == [5..<20])
    }

    @Test("Random lists agree with append, sort and merge")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 77)
        for _ in 0..<500 {
            var ranges: [Range<Int>] = []
            var cursor = generator.next(below: 5)
            for _ in 0..<generator.next(below: 6) {
                let length = 1 + generator.next(below: 4)
                ranges.append(cursor..<(cursor + length))
                cursor += length + 1 + generator.next(below: 4)
            }
            let start = generator.next(below: cursor + 3)
            let newRange = start..<(start + 1 + generator.next(below: 8))
            #expect(insertRange(ranges, newRange) == insertRangeBruteForce(ranges, newRange), "ranges: \(ranges), new: \(newRange)")
        }
    }
}
