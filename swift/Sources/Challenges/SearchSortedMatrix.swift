/// Returns `true` if `target` appears in `matrix`, where every row is sorted ascending and
/// each row's first value is greater than the previous row's last value.
///
/// Read row by row, the matrix is one sorted list of `rows * columns` values. Index `i` of that
/// list lives at `matrix[i / columns][i % columns]`, so a lower-bound binary search over
/// `0..<rows * columns` finds the target without building the list.
/// O(log(m · n)) time, O(1) space.
public func searchSortedMatrix(_ matrix: [[Int]], _ target: Int) -> Bool {
    guard let columns = matrix.first?.count, columns > 0 else { return false }
    var low = 0
    var high = matrix.count * columns
    while low < high {
        let mid = low + (high - low) / 2
        if matrix[mid / columns][mid % columns] < target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    return low < matrix.count * columns && matrix[low / columns][low % columns] == target
}

/// Naive solution: look at every cell. O(m · n) time, O(1) space.
public func searchSortedMatrixBruteForce(_ matrix: [[Int]], _ target: Int) -> Bool {
    for row in matrix {
        for value in row where value == target {
            return true
        }
    }
    return false
}
