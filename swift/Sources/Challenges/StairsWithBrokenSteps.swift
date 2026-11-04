/// Counts the ways to climb from the ground (step 0) to step `n`, going up 1 or 2 steps at a time
/// and never landing on a step listed in `broken`. Numbers in `broken` outside `1...n` are ignored.
/// If step `n` itself is broken, the answer is 0. For `n == 0` there's one way: you're already there.
///
/// ways(i) = ways(i - 1) + ways(i - 2) for a working step and 0 for a broken one, filled bottom-up
/// keeping only the last two values. O(n) time, O(1) extra space.
public func countClimbs(steps n: Int, broken: Set<Int>) -> Int {
    guard n > 0 else { return 1 }
    var twoBelow = 0   // ways to stand on step i - 2 (step -1 doesn't exist: 0)
    var oneBelow = 1   // ways to stand on step i - 1 (the ground: 1)
    for step in 1...n {
        let current = broken.contains(step) ? 0 : oneBelow + twoBelow
        twoBelow = oneBelow
        oneBelow = current
    }
    return oneBelow
}

/// Naive solution: try every sequence of moves with plain recursion. O(φⁿ) time (about 1.618ⁿ),
/// O(n) stack depth.
public func countClimbsBruteForce(steps n: Int, broken: Set<Int>) -> Int {
    func ways(from step: Int) -> Int {
        if step == n { return 1 }
        var total = 0
        for next in [step + 1, step + 2] where next <= n && !broken.contains(next) {
            total += ways(from: next)
        }
        return total
    }
    return ways(from: 0)
}
