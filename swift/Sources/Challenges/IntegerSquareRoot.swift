/// Returns the integer square root of `n`: the largest `r` with `r * r <= n`.
///
/// Binary search on the answer. The condition "r * r > n" is false for small `r` and true
/// from some point on, so the loop finds the first `r` where it's true; the answer is one less.
/// The check is written as `mid > n / mid` so it never multiplies and can't overflow,
/// even for `n == Int.max`. O(log n) time, O(1) space.
public func integerSquareRoot(_ n: Int) -> Int {
    precondition(n >= 0, "n must be non-negative")
    if n < 2 {
        return n
    }
    // For n >= 2, (n / 2 + 1)² > n, so the first "too big" root is in 1...(n / 2 + 1).
    var low = 1
    var high = n / 2 + 1
    while low < high {
        let mid = low + (high - low) / 2
        if mid > n / mid {
            high = mid
        } else {
            low = mid + 1
        }
    }
    return low - 1
}

/// Naive solution: count up from 0 while the next root still fits. O(√n) time, O(1) space.
public func integerSquareRootBruteForce(_ n: Int) -> Int {
    precondition(n >= 0, "n must be non-negative")
    var root = 0
    while root + 1 <= n / (root + 1) {
        root += 1
    }
    return root
}
