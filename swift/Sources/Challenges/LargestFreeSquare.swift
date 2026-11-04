/// Returns the side length of the largest square made only of free cells. Each row is a string of
/// `.` (free) and `#` (taken); all rows have the same length. An empty grid returns 0.
///
/// side[r][c] is the largest free square whose bottom-right corner is (r, c): one more than the
/// smallest of the squares ending above, to the left and diagonally up-left. Only the previous row
/// is kept, with an extra column 0 so the first column needs no special case.
/// O(rows × columns) time, O(columns) extra space.
public func largestFreeSquare(_ rows: [String]) -> Int {
    let grid = rows.map { Array($0) }
    guard let width = grid.first?.count else { return 0 }
    var above = Array(repeating: 0, count: width + 1)   // previous row, shifted one column right
    var best = 0
    for row in grid {
        var current = Array(repeating: 0, count: width + 1)
        for column in 0..<width where row[column] == "." {
            current[column + 1] = 1 + min(above[column + 1], above[column], current[column])
            best = max(best, current[column + 1])
        }
        above = current
    }
    return best
}

/// Naive solution: from every cell, grow a square while it stays free, checking every cell each time.
/// O(r · c · k³) time where k = min(r, c), O(r · c) space for the grid copy.
public func largestFreeSquareBruteForce(_ rows: [String]) -> Int {
    let grid = rows.map { Array($0) }
    guard let width = grid.first?.count else { return 0 }
    var best = 0
    for top in grid.indices {
        for left in 0..<width {
            var size = 1
            while top + size <= grid.count && left + size <= width {
                var allFree = true
                for r in top..<(top + size) {
                    for c in left..<(left + size) where grid[r][c] != "." {
                        allFree = false
                    }
                }
                guard allFree else { break }
                best = max(best, size)
                size += 1
            }
        }
    }
    return best
}
