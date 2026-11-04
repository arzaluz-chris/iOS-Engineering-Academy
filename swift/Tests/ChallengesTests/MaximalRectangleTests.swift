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

@Suite("Maximal Rectangle")
struct MaximalRectangleTests {
    @Test("Examples from the problem statement")
    func examples() {
        let seats = [
            [1, 0, 1, 1, 0],
            [1, 1, 1, 1, 0],
            [0, 1, 1, 1, 1],
            [1, 1, 0, 1, 1],
        ]
        #expect(maximalRectangle(seats) == 6)
        #expect(maximalRectangle([[0, 0], [0, 0]]) == 0)
        #expect(maximalRectangle([[1, 1, 1]]) == 3)
    }

    @Test("Empty grid and grid with empty rows")
    func empty() {
        #expect(maximalRectangle([]) == 0)
        #expect(maximalRectangle([[], []]) == 0)
    }

    @Test("A single column")
    func singleColumn() {
        #expect(maximalRectangle([[1], [1], [0], [1], [1], [1]]) == 3)
    }

    @Test("All ones")
    func allOnes() {
        #expect(maximalRectangle(Array(repeating: Array(repeating: 1, count: 6), count: 4)) == 24)
    }

    @Test("A tall thin block beats a wide short one")
    func shapeMatters() {
        let grid = [
            [0, 1, 0, 0],
            [0, 1, 0, 0],
            [1, 1, 1, 0],
            [0, 1, 0, 0],
            [0, 1, 0, 0],
        ]
        #expect(maximalRectangle(grid) == 5)
    }

    @Test("Random grids agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 31)
        for _ in 0..<400 {
            let rows = generator.next(below: 7)
            let columns = 1 + generator.next(below: 7)
            let density = 2 + generator.next(below: 4)
            let grid = (0..<rows).map { _ in
                (0..<columns).map { _ in generator.next(below: density) == 0 ? 0 : 1 }
            }
            #expect(maximalRectangle(grid) == maximalRectangleBruteForce(grid), "grid: \(grid)")
        }
    }
}
