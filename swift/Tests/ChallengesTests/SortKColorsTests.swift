import Testing
@testable import Challenges

@Suite("Sort K Colors")
struct SortKColorsTests {
    private func sorted(_ colors: [Int], _ k: Int) -> [Int] {
        var copy = colors
        sortKColors(&copy, colorCount: k)
        return copy
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(sorted([3, 1, 4, 2, 1, 4, 3], 4) == [1, 1, 2, 3, 3, 4, 4])
        #expect(sorted([2, 1, 2, 1], 2) == [1, 1, 2, 2])
        #expect(sorted([5, 5, 5], 5) == [5, 5, 5])
    }

    @Test("Empty and single-element lists")
    func tiny() {
        #expect(sorted([], 3) == [])
        #expect(sorted([2], 3) == [2])
    }

    @Test("Only one color")
    func oneColor() {
        #expect(sorted([1, 1, 1, 1], 1) == [1, 1, 1, 1])
    }

    @Test("Some colors never appear")
    func missingColors() {
        #expect(sorted([9, 1, 9, 1, 5], 10) == [1, 1, 5, 9, 9])
    }

    @Test("Already sorted and reversed")
    func orderedInputs() {
        #expect(sorted([1, 2, 3, 4, 5, 6], 6) == [1, 2, 3, 4, 5, 6])
        #expect(sorted([6, 5, 4, 3, 2, 1], 6) == [1, 2, 3, 4, 5, 6])
    }

    @Test("k as large as n")
    func manyColors() {
        let colors = Array((1...500).reversed())
        #expect(sorted(colors, 500) == Array(1...500))
    }

    @Test("Agrees with the pass-per-color version and with sort() on random lists")
    func agreesWithBruteForce() {
        var random = LCG(state: 59)
        for _ in 0..<500 {
            let k = random.next(1...12)
            let colors = (0..<random.next(0...30)).map { _ in random.next(1...k) }
            var slow = colors
            sortKColorsBruteForce(&slow, colorCount: k)
            #expect(sorted(colors, k) == slow)
            #expect(slow == colors.sorted())
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
