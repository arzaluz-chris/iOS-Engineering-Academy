import Testing
@testable import Challenges

@Suite("Largest Free Square")
struct LargestFreeSquareTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(largestFreeSquare([
            "#...#",
            "#....",
            "#...#",
            "..##.",
        ]) == 3)
        #expect(largestFreeSquare([
            ".#",
            "#.",
        ]) == 1)
        #expect(largestFreeSquare(["###"]) == 0)
    }

    @Test("Empty grid and empty rows")
    func empty() {
        #expect(largestFreeSquare([]) == 0)
        #expect(largestFreeSquare(["", ""]) == 0)
    }

    @Test("A single row or column can hold at most a 1 × 1 square")
    func thin() {
        #expect(largestFreeSquare(["....."]) == 1)
        #expect(largestFreeSquare([".", ".", "."]) == 1)
    }

    @Test("A fully free rectangle is limited by its shorter side")
    func allFree() {
        #expect(largestFreeSquare(Array(repeating: "......", count: 4)) == 4)
    }

    @Test("A wide free area with one taken cell in the middle")
    func hole() {
        #expect(largestFreeSquare([
            ".....",
            ".....",
            "..#..",
            ".....",
            ".....",
        ]) == 2)
    }

    @Test("Agrees with growing squares from every cell on random grids")
    func agreesWithBruteForce() {
        var generator = FreeSquareLCG(seed: 5)
        for _ in 0..<300 {
            let height = generator.next(below: 7)
            let width = 1 + generator.next(below: 7)
            let rows = (0..<height).map { _ in
                String((0..<width).map { _ in generator.next(below: 5) == 0 ? "#" as Character : "." })
            }
            #expect(largestFreeSquare(rows) == largestFreeSquareBruteForce(rows), "\(rows)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct FreeSquareLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
