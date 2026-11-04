import Testing
@testable import Challenges

@Suite("Subsets with Duplicates")
struct UniqueSubsetsTests {
    /// Sorts the list of subsets so two answers in different orders compare equal.
    private func normalized(_ subsets: [[Int]]) -> [[Int]] {
        subsets.sorted { $0.lexicographicallyPrecedes($1) }
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(normalized(uniqueSubsets([2, 1, 2])) == normalized([[], [1], [1, 2], [1, 2, 2], [2], [2, 2]]))
        #expect(uniqueSubsets([5]) == [[], [5]])
    }

    @Test("Empty input has one subset, the empty one")
    func empty() {
        #expect(uniqueSubsets([]) == [[]])
    }

    @Test("All values equal gives n + 1 subsets")
    func allEqual() {
        #expect(uniqueSubsets([4, 4, 4]) == [[], [4], [4, 4], [4, 4, 4]])
    }

    @Test("No duplicates gives all 2^n subsets")
    func distinct() {
        #expect(uniqueSubsets([3, 1, 2]).count == 8)
    }

    @Test("Each subset is ascending and none repeats")
    func shape() {
        let result = uniqueSubsets([3, -1, 3, 0, -1])
        #expect(Set(result).count == result.count)
        #expect(result.allSatisfy { $0 == $0.sorted() })
    }

    @Test("Agrees with deduplicating every index subset on random inputs")
    func agreesWithBruteForce() {
        var random = LCG(state: 52)
        for _ in 0..<300 {
            let nums = (0..<random.next(0...9)).map { _ in random.next(-2...3) }
            #expect(normalized(uniqueSubsets(nums)) == normalized(uniqueSubsetsBruteForce(nums)))
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
