/// Counts the ways to give each amount a sign, + or -, so that the signed amounts add up to
/// `target`. Amounts are non-negative; a zero contributes both signs, so it doubles the count.
///
/// If P is the sum of the amounts marked + and the total is T, then P - (T - P) = target, so
/// P = (T + target) / 2. The question becomes "how many subsets add up to P", a 0/1 knapsack count
/// filled with one row and a backward loop so each amount is used at most once.
/// O(n · P) time and O(P) space, with P ≤ the total of the amounts.
public func countSignAssignments(_ amounts: [Int], target: Int) -> Int {
    let total = amounts.reduce(0, +)
    guard abs(target) <= total, (total + target) % 2 == 0 else { return 0 }
    let positiveSum = (total + target) / 2
    var ways = Array(repeating: 0, count: positiveSum + 1)   // ways[s]: subsets so far that add up to s
    ways[0] = 1
    for amount in amounts {
        for sum in stride(from: positiveSum, through: amount, by: -1) {
            ways[sum] += ways[sum - amount]
        }
    }
    return ways[positiveSum]
}

/// Naive solution: try both signs for every amount. O(2ⁿ) time, O(n) stack depth.
public func countSignAssignmentsBruteForce(_ amounts: [Int], target: Int) -> Int {
    func count(from index: Int, sum: Int) -> Int {
        guard index < amounts.count else { return sum == target ? 1 : 0 }
        return count(from: index + 1, sum: sum + amounts[index])
            + count(from: index + 1, sum: sum - amounts[index])
    }
    return count(from: 0, sum: 0)
}
