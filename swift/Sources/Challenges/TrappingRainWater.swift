/// Given the heights of columns of width 1 standing side by side, returns how many units
/// of rain water stay trapped between them.
///
/// The water above a column is the smaller of the tallest column to its left and the tallest
/// to its right (each including the column itself), minus its own height. Two pointers walk
/// in from the ends, each carrying the tallest column seen on its side. The side with the
/// lower maximum is settled first: its water level is fixed by that maximum, because the
/// other side already has something at least as tall. O(n) time, O(1) space.
public func trappedWater(_ heights: [Int]) -> Int {
    var left = 0
    var right = heights.count - 1
    var leftMax = 0
    var rightMax = 0
    var water = 0
    while left <= right {
        if leftMax <= rightMax {
            leftMax = max(leftMax, heights[left])
            water += leftMax - heights[left]
            left += 1
        } else {
            rightMax = max(rightMax, heights[right])
            water += rightMax - heights[right]
            right -= 1
        }
    }
    return water
}

/// Middle step: precompute the tallest column up to each position from both sides.
/// O(n) time, O(n) space.
public func trappedWaterWithPrefixMaxima(_ heights: [Int]) -> Int {
    guard !heights.isEmpty else { return 0 }
    var tallestFromLeft = heights
    for index in heights.indices.dropFirst() {
        tallestFromLeft[index] = max(tallestFromLeft[index - 1], heights[index])
    }
    var tallestFromRight = heights
    for index in heights.indices.reversed().dropFirst() {
        tallestFromRight[index] = max(tallestFromRight[index + 1], heights[index])
    }
    var water = 0
    for index in heights.indices {
        water += min(tallestFromLeft[index], tallestFromRight[index]) - heights[index]
    }
    return water
}

/// Naive solution: for each column, scan left and right for the tallest columns. O(n²) time.
public func trappedWaterBruteForce(_ heights: [Int]) -> Int {
    var water = 0
    for index in heights.indices {
        let tallestLeft = heights[...index].max() ?? 0
        let tallestRight = heights[index...].max() ?? 0
        water += min(tallestLeft, tallestRight) - heights[index]
    }
    return water
}
