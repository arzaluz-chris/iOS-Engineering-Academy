import Testing
@testable import Challenges

@Suite("Combination Sum Without Reuse")
struct CombinationSumNoReuseTests {
    private func normalized(_ lists: [[Int]]) -> [[Int]] {
        lists.sorted { $0.lexicographicallyPrecedes($1) }
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(normalized(combinationSumNoReuse([10, 5, 20, 5, 15, 25], target: 30))
            == normalized([[5, 5, 20], [5, 10, 15], [5, 25], [10, 20]]))
        #expect(combinationSumNoReuse([4, 4, 4], target: 8) == [[4, 4]])
        #expect(combinationSumNoReuse([6, 9], target: 5) == [])
    }

    @Test("Empty candidates")
    func emptyCandidates() {
        #expect(combinationSumNoReuse([], target: 3) == [])
    }

    @Test("A value can't be used more often than it appears")
    func noReuse() {
        #expect(combinationSumNoReuse([3], target: 6) == [])
        #expect(combinationSumNoReuse([3, 3], target: 6) == [[3, 3]])
    }

    @Test("Target equal to one candidate, or to the sum of all")
    func boundaries() {
        #expect(normalized(combinationSumNoReuse([1, 2, 3], target: 3)) == [[1, 2], [3]])
        #expect(combinationSumNoReuse([1, 2, 3], target: 6) == [[1, 2, 3]])
    }

    @Test("Many copies of one value give one combination per count, not per choice of copies")
    func manyCopies() {
        let ones = Array(repeating: 1, count: 20)
        #expect(combinationSumNoReuse(ones, target: 7) == [Array(repeating: 1, count: 7)])
    }

    @Test("Agrees with checking every subset on random inputs")
    func agreesWithBruteForce() {
        var random = LCG(state: 54)
        for _ in 0..<300 {
            let candidates = (0..<random.next(0...10)).map { _ in random.next(1...6) }
            let target = random.next(1...15)
            #expect(normalized(combinationSumNoReuse(candidates, target: target))
                == normalized(combinationSumNoReuseBruteForce(candidates, target: target)))
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
