/// Returns how many minutes pass until no fresh fruit is left in the crate, or `nil` if some fresh
/// fruit can never be reached. In the grid, 0 is an empty slot, 1 a fresh fruit and 2 a rotten one.
/// Every minute, each rotten fruit spoils the fresh fruit directly above, below, left and right of it.
///
/// A breadth-first search that starts from every rotten fruit at once (multi-source BFS). Each round
/// of the outer loop is one minute: it spoils the fresh neighbors of the fruit that went bad the
/// minute before. O(r · c) time and space for an r × c grid.
public func minutesUntilAllRotten(_ grid: [[Int]]) -> Int? {
    var grid = grid
    var spoiling: [(row: Int, column: Int)] = []
    var freshCount = 0
    for row in grid.indices {
        for column in grid[row].indices {
            if grid[row][column] == 2 { spoiling.append((row, column)) }
            if grid[row][column] == 1 { freshCount += 1 }
        }
    }

    let steps = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    var minutes = 0
    while freshCount > 0 && !spoiling.isEmpty {
        var next: [(row: Int, column: Int)] = []
        for cell in spoiling {
            for (rowStep, columnStep) in steps {
                let row = cell.row + rowStep
                let column = cell.column + columnStep
                guard grid.indices.contains(row),
                      grid[row].indices.contains(column),
                      grid[row][column] == 1
                else { continue }
                grid[row][column] = 2
                freshCount -= 1
                next.append((row, column))
            }
        }
        spoiling = next
        minutes += 1
    }
    return freshCount == 0 ? minutes : nil
}

/// Naive solution: simulate minute by minute, rescanning the whole grid each time to find the fruit
/// that spoils next. Up to r · c minutes, each costing O(r · c): O((r · c)²) time, O(r · c) space.
public func minutesUntilAllRottenBySimulation(_ grid: [[Int]]) -> Int? {
    var grid = grid
    var minutes = 0
    while true {
        var spoilsNow: [(row: Int, column: Int)] = []
        var freshLeft = false
        for row in grid.indices {
            for column in grid[row].indices where grid[row][column] == 1 {
                freshLeft = true
                let touchesRotten = [(row - 1, column), (row + 1, column), (row, column - 1), (row, column + 1)]
                    .contains { r, c in grid.indices.contains(r) && grid[r].indices.contains(c) && grid[r][c] == 2 }
                if touchesRotten { spoilsNow.append((row, column)) }
            }
        }
        if !freshLeft { return minutes }
        if spoilsNow.isEmpty { return nil }
        for cell in spoilsNow { grid[cell.row][cell.column] = 2 }
        minutes += 1
    }
}
