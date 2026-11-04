import Testing
@testable import Challenges

@Suite("Search a Sorted Matrix")
struct SearchSortedMatrixTests {
    let shelves = [
        [2, 5, 9, 12],
        [15, 18, 21, 30],
        [34, 40, 47, 51],
    ]

    @Test("Examples from the problem statement")
    func examples() {
        #expect(searchSortedMatrix(shelves, 21))
        #expect(!searchSortedMatrix(shelves, 13))
        #expect(searchSortedMatrix(shelves, 51))
    }

    @Test("Empty matrix and empty rows")
    func empty() {
        #expect(!searchSortedMatrix([], 1))
        #expect(!searchSortedMatrix([[]], 1))
    }

    @Test("Single cell")
    func singleCell() {
        #expect(searchSortedMatrix([[7]], 7))
        #expect(!searchSortedMatrix([[7]], 6))
    }

    @Test("Smaller than everything, larger than everything, first and last cell")
    func extremes() {
        #expect(!searchSortedMatrix(shelves, 1))
        #expect(!searchSortedMatrix(shelves, 52))
        #expect(searchSortedMatrix(shelves, 2))
        #expect(searchSortedMatrix(shelves, 51))
    }

    @Test("A single row and a single column")
    func thinShapes() {
        #expect(searchSortedMatrix([[1, 3, 5, 7]], 5))
        #expect(!searchSortedMatrix([[1, 3, 5, 7]], 4))
        #expect(searchSortedMatrix([[1], [3], [5], [7]], 7))
        #expect(!searchSortedMatrix([[1], [3], [5], [7]], 6))
    }

    @Test("Agrees with the cell-by-cell scan on random matrices")
    func agreesWithBruteForce() {
        var random = LCG(state: 45)
        for _ in 0..<300 {
            let rows = random.next(1...6)
            let columns = random.next(1...6)
            var value = random.next(-20...0)
            var matrix: [[Int]] = []
            for _ in 0..<rows {
                var row: [Int] = []
                for _ in 0..<columns {
                    value += random.next(1...3)
                    row.append(value)
                }
                matrix.append(row)
            }
            for target in -22...(value + 2) {
                #expect(searchSortedMatrix(matrix, target) == searchSortedMatrixBruteForce(matrix, target))
            }
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
