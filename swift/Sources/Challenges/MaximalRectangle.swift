/// Returns the area of the largest all-ones rectangle in a grid of 0s and 1s.
///
/// Row by row, `heights[column]` counts the consecutive 1s ending at that row, which turns
/// each row into a histogram. The largest rectangle whose bottom edge sits on that row is the
/// largest rectangle in the histogram, found with an increasing monotonic stack.
/// O(rows · columns) time, O(columns) space.
public func maximalRectangle(_ grid: [[Int]]) -> Int {
    guard let columns = grid.first?.count else { return 0 }
    var heights = Array(repeating: 0, count: columns)
    var best = 0
    for row in grid {
        for column in 0..<columns {
            heights[column] = row[column] == 1 ? heights[column] + 1 : 0
        }
        best = max(best, maximalRectangleHistogramArea(heights))
    }
    return best
}

/// Largest rectangle under a histogram of bars with width 1. Each bar is pushed and popped once.
/// O(n) time, O(n) space.
func maximalRectangleHistogramArea(_ heights: [Int]) -> Int {
    var rising: [Int] = []
    var best = 0
    for index in 0...heights.count {
        let height = index < heights.count ? heights[index] : 0
        while let top = rising.last, heights[top] >= height {
            rising.removeLast()
            let left = rising.last ?? -1
            best = max(best, heights[top] * (index - left - 1))
        }
        rising.append(index)
    }
    return best
}

/// Naive version: try every rectangle (top, bottom, left, right) and check it with a 2D prefix
/// sum, which counts the 1s inside any rectangle in O(1). O(rows² · columns²) time,
/// O(rows · columns) space.
public func maximalRectangleBruteForce(_ grid: [[Int]]) -> Int {
    let rows = grid.count
    guard let columns = grid.first?.count else { return 0 }
    // ones[r][c] = number of 1s in grid[0..<r][0..<c]
    var ones = Array(repeating: Array(repeating: 0, count: columns + 1), count: rows + 1)
    for r in 0..<rows {
        for c in 0..<columns {
            ones[r + 1][c + 1] = grid[r][c] + ones[r][c + 1] + ones[r + 1][c] - ones[r][c]
        }
    }
    var best = 0
    for top in 0..<rows {
        for bottom in top..<rows {
            for left in 0..<columns {
                for right in left..<columns {
                    let area = (bottom - top + 1) * (right - left + 1)
                    let count = ones[bottom + 1][right + 1] - ones[top][right + 1]
                        - ones[bottom + 1][left] + ones[top][left]
                    if count == area {
                        best = max(best, area)
                    }
                }
            }
        }
    }
    return best
}
