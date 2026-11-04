/// Returns `true` if `word` can be spelled by a path through `grid` that moves up, down, left or
/// right one cell at a time and uses each cell at most once.
///
/// Backtracking from every cell. `match(row, column, index)` checks that the cell holds
/// `word[index]`, marks it as used by overwriting it with a sentinel, tries the four neighbors
/// for `index + 1`, and puts the letter back before returning. A letter count check up front
/// rejects words that need more of some letter than the grid has.
/// O(m · n · 3^L) time for an m × n grid and a word of length L (after the first step each
/// cell has at most 3 unvisited neighbors to try), O(L) recursion depth, plus O(m · n) for the
/// working copy of the grid.
public func gridContainsWord(_ grid: [[Character]], _ word: String) -> Bool {
    let letters = Array(word)
    guard !letters.isEmpty else { return true }
    let rows = grid.count
    let columns = grid.first?.count ?? 0
    guard rows > 0, columns > 0, letters.count <= rows * columns else { return false }

    var available: [Character: Int] = [:]
    for row in grid {
        for letter in row {
            available[letter, default: 0] += 1
        }
    }
    for (letter, needed) in Dictionary(letters.map { ($0, 1) }, uniquingKeysWith: +) {
        if available[letter, default: 0] < needed {
            return false
        }
    }

    var board = grid
    let used: Character = "\0"

    func match(_ row: Int, _ column: Int, _ index: Int) -> Bool {
        guard row >= 0, row < rows, column >= 0, column < columns,
              board[row][column] == letters[index] else { return false }
        if index == letters.count - 1 {
            return true
        }
        board[row][column] = used
        let found = match(row + 1, column, index + 1)
            || match(row - 1, column, index + 1)
            || match(row, column + 1, index + 1)
            || match(row, column - 1, index + 1)
        board[row][column] = letters[index]
        return found
    }

    for row in 0..<rows {
        for column in 0..<columns where match(row, column, 0) {
            return true
        }
    }
    return false
}

/// Naive solution: the same search, but each path carries its own copy of the visited set,
/// and there's no letter count check. Correct, and much slower: every step copies a Set.
public func gridContainsWordBruteForce(_ grid: [[Character]], _ word: String) -> Bool {
    let letters = Array(word)
    guard !letters.isEmpty else { return true }

    func search(_ row: Int, _ column: Int, _ index: Int, _ visited: Set<[Int]>) -> Bool {
        guard row >= 0, row < grid.count, column >= 0, column < grid[row].count,
              !visited.contains([row, column]), grid[row][column] == letters[index] else { return false }
        if index == letters.count - 1 {
            return true
        }
        let next = visited.union([[row, column]])
        return search(row + 1, column, index + 1, next)
            || search(row - 1, column, index + 1, next)
            || search(row, column + 1, index + 1, next)
            || search(row, column - 1, index + 1, next)
    }

    for row in grid.indices {
        for column in grid[row].indices where search(row, column, 0, []) {
            return true
        }
    }
    return false
}
