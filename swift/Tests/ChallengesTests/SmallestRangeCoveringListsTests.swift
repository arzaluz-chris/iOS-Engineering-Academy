import Testing
@testable import Challenges

@Suite("Smallest Range Covering K Lists")
struct SmallestRangeCoveringListsTests {
    /// Independent check: every pair of numbers as the endpoints.
    private func smallestByAllPairs(_ lists: [[Int]]) -> ClosedRange<Int>? {
        guard !lists.isEmpty, lists.allSatisfy({ !$0.isEmpty }) else { return nil }
        let all = lists.joined().sorted()
        var best: ClosedRange<Int>?
        for start in all {
            for end in all where end >= start {
                guard lists.allSatisfy({ $0.contains { (start...end).contains($0) } }) else { continue }
                if best == nil
                    || end - start < best!.upperBound - best!.lowerBound
                    || (end - start == best!.upperBound - best!.lowerBound && start < best!.lowerBound) {
                    best = start...end
                }
            }
        }
        return best
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(smallestRangeCoveringLists([[1, 9, 20], [4, 12, 30], [8, 14, 25]]) == 8...12)
        #expect(smallestRangeCoveringLists([[1, 2, 3], [1, 2, 3], [1, 2, 3]]) == 1...1)
        #expect(smallestRangeCoveringLists([[10], [3, 50]]) == 3...10)
    }

    @Test("A single list gives a range of one number")
    func singleList() {
        #expect(smallestRangeCoveringLists([[4, 7, 9]]) == 4...4)
    }

    @Test("No lists, or an empty list")
    func empties() {
        #expect(smallestRangeCoveringLists([]) == nil)
        #expect(smallestRangeCoveringLists([[1, 2], []]) == nil)
    }

    @Test("Ties go to the smaller start")
    func ties() {
        #expect(smallestRangeCoveringLists([[1, 10], [3, 12]]) == 1...3)
    }

    @Test("Duplicates and negatives")
    func duplicatesAndNegatives() {
        #expect(smallestRangeCoveringLists([[-5, -5, 0], [-3, 2], [-4, 6]]) == -5...(-3))
    }

    @Test("Agrees with both brute forces on random lists")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 77)
        for _ in 0..<300 {
            let lists = (0..<generator.next(in: 1...4)).map { _ in
                (0..<generator.next(in: 1...6)).map { _ in generator.next(in: -15...15) }.sorted()
            }
            let fast = smallestRangeCoveringLists(lists)
            #expect(fast == smallestRangeCoveringListsByStart(lists))
            #expect(fast == smallestByAllPairs(lists))
        }
    }
}
