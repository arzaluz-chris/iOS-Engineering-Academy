import Testing
@testable import Challenges

@Suite("Word Search")
struct WordSearchGridTests {
    let board: [[Character]] = [
        ["C", "A", "T", "S"],
        ["O", "R", "E", "N"],
        ["D", "E", "A", "R"],
    ]

    @Test("Examples from the problem statement")
    func examples() {
        #expect(gridContainsWord(board, "CARE"))
        #expect(gridContainsWord(board, "TEAR"))
        #expect(!gridContainsWord(board, "CATCH"))
        #expect(!gridContainsWord(board, "RACER"))
    }

    @Test("A cell can't be used twice")
    func noReuse() {
        #expect(!gridContainsWord([["A", "B"]], "ABA"))
        #expect(gridContainsWord([["A", "B", "A"]], "ABA"))
    }

    @Test("No diagonal moves")
    func noDiagonals() {
        #expect(!gridContainsWord([["A", "X"], ["X", "B"]], "AB"))
    }

    @Test("Single-cell grid and single-letter words")
    func singleCell() {
        #expect(gridContainsWord([["Q"]], "Q"))
        #expect(!gridContainsWord([["Q"]], "QQ"))
        #expect(gridContainsWord(board, "D"))
        #expect(!gridContainsWord(board, "Z"))
    }

    @Test("Word longer than the grid has cells")
    func tooLong() {
        #expect(!gridContainsWord([["A", "A"], ["A", "A"]], "AAAAA"))
        #expect(gridContainsWord([["A", "A"], ["A", "A"]], "AAAA"))
    }

    @Test("A path that has to turn back on itself in the grid")
    func snake() {
        let grid: [[Character]] = [
            ["A", "B", "C"],
            ["F", "E", "D"],
            ["G", "H", "I"],
        ]
        #expect(gridContainsWord(grid, "ABCDEFGHI"))
        #expect(!gridContainsWord(grid, "ABCDEFGHA"))
    }

    @Test("The search undoes its marks: the same grid answers several queries")
    func marksAreUndone() {
        let grid: [[Character]] = [["A", "B"], ["B", "A"]]
        #expect(gridContainsWord(grid, "ABAB"))
        #expect(gridContainsWord(grid, "ABAB"))
        #expect(grid == [["A", "B"], ["B", "A"]])
    }

    @Test("Agrees with the copy-the-visited-set search on random grids")
    func agreesWithBruteForce() {
        var random = LCG(state: 55)
        let letters: [Character] = ["A", "B", "C"]
        for _ in 0..<300 {
            let rows = random.next(1...4)
            let columns = random.next(1...4)
            let grid = (0..<rows).map { _ in (0..<columns).map { _ in letters[random.next(0...2)] } }
            let word = String((0..<random.next(1...6)).map { _ in letters[random.next(0...2)] })
            #expect(gridContainsWord(grid, word) == gridContainsWordBruteForce(grid, word))
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
