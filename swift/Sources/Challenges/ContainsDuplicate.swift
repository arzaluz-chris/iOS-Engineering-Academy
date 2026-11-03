/// Returns whether any value appears at least twice in `nums`.
///
/// Walks the list once and keeps what it has seen in a `Set`.
/// `insert` returns `inserted == false` when the value was already there.
/// O(n) time on average, O(n) space.
public func containsDuplicate(_ nums: [Int]) -> Bool {
    var seen = Set<Int>()
    seen.reserveCapacity(nums.count)
    for value in nums {
        if !seen.insert(value).inserted {
            return true
        }
    }
    return false
}

/// Alternative with no extra memory proportional to n (besides the sorted copy):
/// sort and compare neighbors. O(n log n) time.
public func containsDuplicateBySorting(_ nums: [Int]) -> Bool {
    let sorted = nums.sorted()
    for i in sorted.indices.dropFirst() where sorted[i] == sorted[i - 1] {
        return true
    }
    return false
}
