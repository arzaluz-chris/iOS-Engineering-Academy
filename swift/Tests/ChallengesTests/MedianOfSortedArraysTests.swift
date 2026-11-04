import Testing
@testable import Challenges

@Suite("Median of Two Sorted Arrays")
struct MedianOfSortedArraysTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(medianOfSortedArrays([1, 4, 9], [2, 3]) == 3)
        #expect(medianOfSortedArrays([10, 20], [15, 40]) == 17.5)
        #expect(medianOfSortedArrays([], [6]) == 6)
    }

    @Test("One array is empty")
    func oneEmpty() {
        #expect(medianOfSortedArrays([1, 2, 3, 4], []) == 2.5)
        #expect(medianOfSortedArrays([], [5, 7, 9]) == 7)
    }

    @Test("All of one array comes before the other")
    func disjointRanges() {
        #expect(medianOfSortedArrays([1, 2, 3], [10, 11, 12]) == 6.5)
        #expect(medianOfSortedArrays([10, 11, 12], [1, 2]) == 10)
    }

    @Test("Duplicates and equal values across the arrays")
    func duplicates() {
        #expect(medianOfSortedArrays([2, 2, 2], [2, 2]) == 2)
        #expect(medianOfSortedArrays([1, 3, 3], [3, 3, 8]) == 3)
    }

    @Test("Negative values and a negative half")
    func negatives() {
        #expect(medianOfSortedArrays([-5, -3], [-4]) == -4)
        #expect(medianOfSortedArrays([-3], [0]) == -1.5)
    }

    @Test("Extreme values don't overflow")
    func extremes() {
        #expect(medianOfSortedArrays([1_000_000], [1_000_000]) == 1_000_000)
        #expect(medianOfSortedArrays([-1_000_000], [1_000_000]) == 0)
    }

    @Test("Agrees with merging on random arrays")
    func agreesWithBruteForce() {
        var random = LCG(state: 50)
        for _ in 0..<2_000 {
            let first = (0..<random.next(0...9)).map { _ in random.next(-15...15) }.sorted()
            var second = (0..<random.next(0...9)).map { _ in random.next(-15...15) }.sorted()
            if first.isEmpty && second.isEmpty {
                second = [random.next(-15...15)]
            }
            #expect(medianOfSortedArrays(first, second) == medianOfSortedArraysBruteForce(first, second))
        }
    }
}

/// Small deterministic generator so failures reproduce.
private struct LCG {
    var state: UInt64
    mutating func next(_ range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return range.lowerBound + Int((state >> 33) % UInt64(range.count))
    }
}
