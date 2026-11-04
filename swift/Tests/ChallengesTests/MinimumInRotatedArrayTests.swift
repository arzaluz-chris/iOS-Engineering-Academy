import Testing
@testable import Challenges

@Suite("Minimum in a Rotated Sorted Array")
struct MinimumInRotatedArrayTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(minimumInRotatedArray([40, 55, 70, 5, 12, 33]) == 5)
        #expect(minimumInRotatedArray([8, 1, 3, 4]) == 1)
        #expect(minimumInRotatedArray([2, 4, 6, 9]) == 2)
    }

    @Test("Single element and two elements")
    func tiny() {
        #expect(minimumInRotatedArray([7]) == 7)
        #expect(minimumInRotatedArray([3, 9]) == 3)
        #expect(minimumInRotatedArray([9, 3]) == 3)
    }

    @Test("Minimum at the last position")
    func minimumLast() {
        #expect(minimumInRotatedArray([2, 3, 4, 5, 1]) == 1)
    }

    @Test("Negative values")
    func negatives() {
        #expect(minimumInRotatedArray([0, 4, -10, -3]) == -10)
    }

    @Test("Every rotation of sorted arrays of length 1 to 12")
    func everyRotation() {
        var random = LCG(state: 47)
        for length in 1...12 {
            var sorted: [Int] = []
            var value = random.next(-50...50)
            for _ in 0..<length {
                value += random.next(1...9)
                sorted.append(value)
            }
            for shift in 0..<length {
                let rotated = Array(sorted[shift...] + sorted[..<shift])
                #expect(minimumInRotatedArray(rotated) == minimumInRotatedArrayBruteForce(rotated))
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
