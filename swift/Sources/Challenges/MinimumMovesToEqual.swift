/// Returns the fewest moves to make every value in `nums` equal, where a move adds 1 to or
/// subtracts 1 from one value.
///
/// The cost of a final value `x` is the sum of `|v - x|`, and that sum is smallest when `x` is
/// a median: moving `x` away from the median moves it away from at least as many values as it
/// moves toward. So the answer only needs the median, the (n / 2)-th smallest value, and
/// quickselect finds it without sorting. Pivots are picked at random, so the expected time is
/// O(n) (the worst case is O(n²) with very unlucky pivots), and the three-way partition keeps
/// lists full of equal values linear too. O(n) space for the working copy.
public func minimumMovesToEqual(_ nums: [Int]) -> Int {
    guard !nums.isEmpty else { return 0 }
    var values = nums
    let k = values.count / 2
    var low = 0
    var high = values.count

    // Quickselect with a three-way partition: smaller, equal, greater than the pivot.
    // Keep only the region that contains index k; stop when k lands among the equal ones.
    while high - low > 1 {
        let pivot = values[Int.random(in: low..<high)]
        var lessEnd = low
        var i = low
        var greaterStart = high
        while i < greaterStart {
            if values[i] < pivot {
                values.swapAt(i, lessEnd)
                lessEnd += 1
                i += 1
            } else if values[i] > pivot {
                greaterStart -= 1
                values.swapAt(i, greaterStart)
            } else {
                i += 1
            }
        }
        if k < lessEnd {
            high = lessEnd
        } else if k >= greaterStart {
            low = greaterStart
        } else {
            break
        }
    }

    let median = values[k]
    var moves = 0
    for value in nums {
        moves += abs(value - median)
    }
    return moves
}

/// Naive solution: try every value in the list as the target and keep the cheapest.
/// O(n²) time, O(1) space.
public func minimumMovesToEqualBruteForce(_ nums: [Int]) -> Int {
    var best: Int?
    for candidate in nums {
        var moves = 0
        for value in nums {
            moves += abs(value - candidate)
        }
        best = min(best ?? moves, moves)
    }
    return best ?? 0
}

/// Middle solution: sort a copy and read the median. O(n log n) time, O(n) space.
public func minimumMovesToEqualBySorting(_ nums: [Int]) -> Int {
    guard !nums.isEmpty else { return 0 }
    let median = nums.sorted()[nums.count / 2]
    var moves = 0
    for value in nums {
        moves += abs(value - median)
    }
    return moves
}
