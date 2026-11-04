/// Returns every distinct subset of `nums`, which may contain repeated values. Each subset is in
/// ascending order, and no subset appears twice.
///
/// Sort first, so equal values sit next to each other. The backtracking is the lesson's subsets
/// generator with one rule added: at a given level, after trying a value, skip the following
/// copies of it (`i > start && sorted[i] == sorted[i - 1]`). Any subset those copies would
/// start was already produced by the first copy.
/// O(n · 2^n) time in the worst case (all values distinct), O(n) space besides the output.
public func uniqueSubsets(_ nums: [Int]) -> [[Int]] {
    let sorted = nums.sorted()
    var results: [[Int]] = []
    var current: [Int] = []

    func explore(from start: Int) {
        results.append(current)
        for i in start..<sorted.count {
            if i > start && sorted[i] == sorted[i - 1] {
                continue
            }
            current.append(sorted[i])
            explore(from: i + 1)
            current.removeLast()
        }
    }

    explore(from: 0)
    return results
}

/// Naive solution: generate all 2^n index subsets and let a Set drop the repeats.
/// O(n · 2^n) time no matter how many values repeat, O(n · 2^n) space for the Set.
public func uniqueSubsetsBruteForce(_ nums: [Int]) -> [[Int]] {
    let sorted = nums.sorted()
    var seen = Set<[Int]>()
    var results: [[Int]] = []
    for selection in 0..<(1 << sorted.count) {
        var subset: [Int] = []
        for index in sorted.indices where selection & (1 << index) != 0 {
            subset.append(sorted[index])
        }
        if seen.insert(subset).inserted {
            results.append(subset)
        }
    }
    return results
}
