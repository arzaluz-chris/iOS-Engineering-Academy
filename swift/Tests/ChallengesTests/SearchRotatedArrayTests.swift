import Testing
@testable import Challenges

@Suite("Search a Rotated Sorted Array")
struct SearchRotatedArrayTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(searchRotatedArray([40, 55, 70, 5, 12, 33], 12) == 4)
        #expect(searchRotatedArray([40, 55, 70, 5, 12, 33], 55) == 1)
        #expect(searchRotatedArray([40, 55, 70, 5, 12, 33], 20) == nil)
    }

    @Test("Empty and single-element arrays")
    func tiny() {
        #expect(searchRotatedArray([], 3) == nil)
        #expect(searchRotatedArray([3], 3) == 0)
        #expect(searchRotatedArray([3], 4) == nil)
    }

    @Test("Not rotated at all")
    func notRotated() {
        #expect(searchRotatedArray([1, 4, 6, 8], 1) == 0)
        #expect(searchRotatedArray([1, 4, 6, 8], 8) == 3)
        #expect(searchRotatedArray([1, 4, 6, 8], 5) == nil)
    }

    @Test("Target between the two runs, or outside every value")
    func gaps() {
        // Runs: [50, 60] and [10, 20, 30]. 40 fits neither; 5 and 70 are outside both.
        let nums = [50, 60, 10, 20, 30]
        #expect(searchRotatedArray(nums, 40) == nil)
        #expect(searchRotatedArray(nums, 5) == nil)
        #expect(searchRotatedArray(nums, 70) == nil)
        #expect(searchRotatedArray(nums, 30) == 4)
        #expect(searchRotatedArray(nums, 50) == 0)
    }

    @Test("Every rotation and every target, against linear search")
    func agreesWithBruteForce() {
        var random = LCG(state: 48)
        for length in 1...10 {
            var sorted: [Int] = []
            var value = random.next(-30...30)
            for _ in 0..<length {
                value += random.next(1...4)
                sorted.append(value)
            }
            for shift in 0..<length {
                let rotated = Array(sorted[shift...] + sorted[..<shift])
                for target in (sorted[0] - 2)...(sorted[length - 1] + 2) {
                    #expect(searchRotatedArray(rotated, target) == searchRotatedArrayBruteForce(rotated, target))
                }
            }
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
