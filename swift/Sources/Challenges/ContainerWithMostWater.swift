/// Given the heights of vertical boards standing one unit apart, returns the largest amount
/// of water two boards can hold between them. The water's height is the shorter board's height
/// and its width is the distance between the two boards; boards in between don't matter.
///
/// Converging pointers: start with the widest pair, and always move the shorter board inward,
/// because every pair that keeps the shorter board and is narrower can only hold less.
/// O(n) time, O(1) space.
public func largestTank(_ heights: [Int]) -> Int {
    var left = 0
    var right = heights.count - 1
    var best = 0
    while left < right {
        let height = min(heights[left], heights[right])
        best = max(best, height * (right - left))
        if heights[left] < heights[right] {
            left += 1
        } else {
            right -= 1
        }
    }
    return best
}

/// Naive solution: try every pair of boards. O(n²) time, O(1) space.
public func largestTankBruteForce(_ heights: [Int]) -> Int {
    var best = 0
    for i in heights.indices {
        for j in (i + 1)..<heights.count {
            best = max(best, min(heights[i], heights[j]) * (j - i))
        }
    }
    return best
}
