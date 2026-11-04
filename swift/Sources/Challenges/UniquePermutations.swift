/// Returns every distinct ordering of `nums`, which may contain repeated values.
///
/// Sort first, then run the lesson's permutations generator with one extra rule: a copy of a
/// value can only be placed if the copy just before it is already in use. Equal values are then
/// always placed in their original left-to-right order, so each distinct arrangement is built
/// exactly once. O(n · n!) time in the worst case (all values distinct), O(n) space besides
/// the output.
public func uniquePermutations(_ nums: [Int]) -> [[Int]] {
    let sorted = nums.sorted()
    var results: [[Int]] = []
    var current: [Int] = []
    var used = Array(repeating: false, count: sorted.count)

    func explore() {
        if current.count == sorted.count {
            results.append(current)
            return
        }
        for i in sorted.indices where !used[i] {
            if i > 0 && sorted[i] == sorted[i - 1] && !used[i - 1] {
                continue
            }
            used[i] = true
            current.append(sorted[i])
            explore()
            current.removeLast()
            used[i] = false
        }
    }

    explore()
    return results
}

/// Naive solution: generate all n! index orderings and let a Set drop the repeats.
/// O(n · n!) time even when most orderings repeat, O(n · n!) space for the Set.
public func uniquePermutationsBruteForce(_ nums: [Int]) -> [[Int]] {
    var seen = Set<[Int]>()
    var results: [[Int]] = []
    var current: [Int] = []
    var used = Array(repeating: false, count: nums.count)

    func explore() {
        if current.count == nums.count {
            if seen.insert(current).inserted {
                results.append(current)
            }
            return
        }
        for i in nums.indices where !used[i] {
            used[i] = true
            current.append(nums[i])
            explore()
            current.removeLast()
            used[i] = false
        }
    }

    explore()
    return results
}
