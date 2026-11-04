import Testing
@testable import Challenges

@Suite("Minimum Moves to Equal Values")
struct MinimumMovesToEqualTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(minimumMovesToEqual([70, 72, 68, 75]) == 9)
        #expect(minimumMovesToEqual([1, 10, 2, 9]) == 16)
        #expect(minimumMovesToEqual([4]) == 0)
    }

    @Test("Empty list needs no moves")
    func empty() {
        #expect(minimumMovesToEqual([]) == 0)
    }

    @Test("Already equal")
    func alreadyEqual() {
        #expect(minimumMovesToEqual([3, 3, 3, 3]) == 0)
        #expect(minimumMovesToEqual(Array(repeating: 7, count: 100_000)) == 0)
    }

    @Test("Negative values and wide ranges")
    func negatives() {
        #expect(minimumMovesToEqual([-5, 0, 5]) == 10)
        #expect(minimumMovesToEqual([-1_000_000_000, 1_000_000_000]) == 2_000_000_000)
    }

    @Test("The mean isn't the answer")
    func meanIsWrong() {
        // The median, 1, costs 96 moves. The mean, 25, costs 24 · 3 + 72 = 144.
        #expect(minimumMovesToEqual([1, 1, 1, 97]) == 96)
    }

    @Test("Doesn't modify the input")
    func inputUnchanged() {
        let nums = [5, 3, 9, 1]
        _ = minimumMovesToEqual(nums)
        #expect(nums == [5, 3, 9, 1])
    }

    @Test("Agrees with the naive and sorting versions on random lists")
    func agreesWithBruteForce() {
        var random = LCG(state: 60)
        for _ in 0..<500 {
            let nums = (0..<random.next(0...25)).map { _ in random.next(-20...20) }
            let fast = minimumMovesToEqual(nums)
            #expect(fast == minimumMovesToEqualBruteForce(nums))
            #expect(fast == minimumMovesToEqualBySorting(nums))
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
