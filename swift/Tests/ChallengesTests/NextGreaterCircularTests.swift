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

@Suite("Next Greater Element in a Circular Array")
struct NextGreaterCircularTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(nextGreaterCircular([3, 8, 4, 1, 6]) == [8, -1, 6, 6, 8])
        #expect(nextGreaterCircular([5, 4, 3, 2]) == [-1, 5, 5, 5])
        #expect(nextGreaterCircular([2, 2, 2]) == [-1, -1, -1])
    }

    @Test("Empty and single-element arrays")
    func tiny() {
        #expect(nextGreaterCircular([]) == [])
        #expect(nextGreaterCircular([7]) == [-1])
    }

    @Test("Equal values aren't greater, but a bigger one further around is found")
    func duplicates() {
        #expect(nextGreaterCircular([1, 3, 1, 3]) == [3, -1, 3, -1])
        #expect(nextGreaterCircular([4, 1, 4]) == [-1, 4, -1])
    }

    @Test("Negative values")
    func negatives() {
        #expect(nextGreaterCircular([-5, -9, -2]) == [-2, -2, -1])
    }

    @Test("Random arrays agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 99)
        for _ in 0..<500 {
            let count = generator.next(below: 14)
            let values = (0..<count).map { _ in generator.next(below: 7) - 3 }
            #expect(nextGreaterCircular(values) == nextGreaterCircularBruteForce(values), "input: \(values)")
        }
    }
}
