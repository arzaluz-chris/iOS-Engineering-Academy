/// Returns every distinct combination of `candidates` that adds up to `target`, using each
/// position at most once. Candidates are positive and may repeat; each combination is in
/// ascending order and no combination appears twice.
///
/// Sort, then backtrack with the remaining amount. Two cuts: `break` as soon as a candidate is
/// bigger than what's left (every later one is too), and `continue` past a value equal to the
/// previous one at the same level, because the first copy already produced those combinations.
/// O(2^n · n) time in the worst case, O(n) space besides the output.
public func combinationSumNoReuse(_ candidates: [Int], target: Int) -> [[Int]] {
    let sorted = candidates.sorted()
    var results: [[Int]] = []
    var current: [Int] = []

    func explore(from start: Int, remaining: Int) {
        if remaining == 0 {
            results.append(current)
            return
        }
        for i in start..<sorted.count {
            if sorted[i] > remaining {
                break
            }
            if i > start && sorted[i] == sorted[i - 1] {
                continue
            }
            current.append(sorted[i])
            explore(from: i + 1, remaining: remaining - sorted[i])
            current.removeLast()
        }
    }

    explore(from: 0, remaining: target)
    return results
}

/// Naive solution: try every subset of positions, keep the ones with the right sum, and let a
/// Set drop the repeats. O(n · 2^n) time, plus the Set.
public func combinationSumNoReuseBruteForce(_ candidates: [Int], target: Int) -> [[Int]] {
    let sorted = candidates.sorted()
    var seen = Set<[Int]>()
    var results: [[Int]] = []
    for selection in 0..<(1 << sorted.count) {
        var combination: [Int] = []
        var sum = 0
        for index in sorted.indices where selection & (1 << index) != 0 {
            combination.append(sorted[index])
            sum += sorted[index]
        }
        if sum == target && seen.insert(combination).inserted {
            results.append(combination)
        }
    }
    return results
}
