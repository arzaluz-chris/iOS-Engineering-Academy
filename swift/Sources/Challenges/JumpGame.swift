/// Returns whether you can get from platform 0 to the last platform, where `maxJump[i]` is the
/// farthest you can jump forward from platform i (you may jump any shorter distance too).
/// An empty array has nothing to reach and returns `true`.
///
/// Greedy: walk the platforms keeping `farthest`, the farthest index reachable so far. Every
/// platform up to `farthest` is reachable, because you can always jump short. If the walk reaches
/// a platform beyond `farthest`, it's cut off, and so is everything after it.
/// O(n) time, O(1) extra space.
public func canReachLastPlatform(_ maxJump: [Int]) -> Bool {
    var farthest = 0
    for (index, jump) in maxJump.enumerated() {
        guard index <= farthest else { return false }
        farthest = max(farthest, index + jump)
    }
    return true
}

/// Naive solution: mark every platform reachable from a reachable one. O(n · J) time where J is
/// the largest jump (O(n²) in the worst case), O(n) space.
public func canReachLastPlatformBruteForce(_ maxJump: [Int]) -> Bool {
    guard !maxJump.isEmpty else { return true }
    var reachable = Array(repeating: false, count: maxJump.count)
    reachable[0] = true
    for index in maxJump.indices where reachable[index] {
        for next in stride(from: index + 1, through: min(maxJump.count - 1, index + maxJump[index]), by: 1) {
            reachable[next] = true
        }
    }
    return reachable[maxJump.count - 1]
}
