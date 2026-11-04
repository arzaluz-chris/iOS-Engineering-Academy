/// Returns the most revenue you can collect by choosing slots on a looping carousel, where no two
/// chosen slots are next to each other and the last slot is next to the first.
/// A carousel with a single slot can use it.
///
/// The first and last slots can't both be chosen, so the answer is the better of two straight-line
/// problems: without the last slot, and without the first. Each is the "no two adjacent" recurrence
/// best = max(best, bestBeforePrevious + value) with two rolling variables.
/// O(n) time, O(1) extra space.
public func bestLoopRevenue(_ revenue: [Int]) -> Int {
    guard revenue.count > 1 else { return revenue.first ?? 0 }
    let withoutLast = bestStraightLineRevenue(revenue, in: 0..<(revenue.count - 1))
    let withoutFirst = bestStraightLineRevenue(revenue, in: 1..<revenue.count)
    return max(withoutLast, withoutFirst)
}

/// "No two adjacent" on the slots in `range`, treated as a straight line.
private func bestStraightLineRevenue(_ revenue: [Int], in range: Range<Int>) -> Int {
    var best = 0                 // best total using slots up to the previous one
    var bestBeforePrevious = 0   // best total using slots up to the one before that
    for index in range {
        let current = max(best, bestBeforePrevious + revenue[index])
        bestBeforePrevious = best
        best = current
    }
    return best
}

/// Naive solution: try every subset of slots and keep the valid ones. O(2ⁿ · n) time, O(1) space.
/// Only practical for small carousels (the tests use up to 16 slots).
public func bestLoopRevenueBruteForce(_ revenue: [Int]) -> Int {
    let count = revenue.count
    var best = 0
    for mask in 0..<(1 << count) {
        var total = 0
        var isValid = true
        for index in 0..<count where mask & (1 << index) != 0 {
            let next = (index + 1) % count
            if count > 1 && mask & (1 << next) != 0 {
                isValid = false
                break
            }
            total += revenue[index]
        }
        if isValid { best = max(best, total) }
    }
    return best
}
