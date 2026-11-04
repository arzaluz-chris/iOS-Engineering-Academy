/// Returns the index of `target` in `nums`, a list of distinct values that was sorted ascending
/// and then rotated, or `nil` if it isn't there.
///
/// Two boundary searches. The first finds `start`, the index of the minimum: the first index
/// whose value is `<= nums.last`. That splits the array into two sorted runs, `0..<start` and
/// `start..<count`. Comparing the target with `nums.last` says which run could hold it, and a
/// lower bound on that run finishes the job. O(log n) time, O(1) space.
public func searchRotatedArray(_ nums: [Int], _ target: Int) -> Int? {
    guard let last = nums.last else { return nil }

    var low = 0
    var high = nums.count - 1
    while low < high {
        let mid = low + (high - low) / 2
        if nums[mid] > last {
            low = mid + 1
        } else {
            high = mid
        }
    }
    let start = low

    // Values <= last live in the right run; bigger ones in the left run.
    low = target <= last ? start : 0
    high = target <= last ? nums.count : start
    while low < high {
        let mid = low + (high - low) / 2
        if nums[mid] < target {
            low = mid + 1
        } else {
            high = mid
        }
    }
    // `low` is always a valid index here: in the right run, nums.last >= target stops the
    // search by count - 1 at the latest; in the left run, `low` is at most `start`.
    return nums[low] == target ? low : nil
}

/// Naive solution: linear search. O(n) time, O(1) space.
public func searchRotatedArrayBruteForce(_ nums: [Int], _ target: Int) -> Int? {
    nums.firstIndex(of: target)
}
