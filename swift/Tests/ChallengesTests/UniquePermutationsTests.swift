import Testing
@testable import Challenges

@Suite("Unique Permutations")
struct UniquePermutationsTests {
    private func normalized(_ lists: [[Int]]) -> [[Int]] {
        lists.sorted { $0.lexicographicallyPrecedes($1) }
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(uniquePermutations([2, 1, 2]) == [[1, 2, 2], [2, 1, 2], [2, 2, 1]])
        #expect(uniquePermutations([3, 3]) == [[3, 3]])
    }

    @Test("Empty input has one arrangement, the empty one")
    func empty() {
        #expect(uniquePermutations([]) == [[]])
    }

    @Test("Single value")
    func single() {
        #expect(uniquePermutations([9]) == [[9]])
    }

    @Test("Distinct values give n! arrangements")
    func distinct() {
        #expect(uniquePermutations([1, 2, 3, 4]).count == 24)
    }

    @Test("Counts match the multinomial formula")
    func multinomial() {
        // 6! / (2! · 2! · 2!) = 90
        #expect(uniquePermutations([1, 1, 2, 2, 3, 3]).count == 90)
        // 5! / (4! · 1!) = 5
        #expect(uniquePermutations([0, 0, 0, 0, 7]).count == 5)
    }

    @Test("Agrees with deduplicating every ordering on random inputs")
    func agreesWithBruteForce() {
        var random = LCG(state: 53)
        for _ in 0..<200 {
            let nums = (0..<random.next(0...6)).map { _ in random.next(-1...2) }
            let fast = uniquePermutations(nums)
            #expect(Set(fast).count == fast.count)
            #expect(normalized(fast) == normalized(uniquePermutationsBruteForce(nums)))
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
