/// Returns the smallest value of `nums`, a list of distinct values that was sorted ascending
/// and then rotated (its first k elements moved to the end, for some unknown k).
///
/// Compared with the last element, every value of the left run is greater and every value of
/// the right run (which starts with the minimum) is smaller or equal. "nums[i] <= nums.last"
/// is false and then true, so a boundary binary search finds where the right run starts.
/// O(log n) time, O(1) space.
public func minimumInRotatedArray(_ nums: [Int]) -> Int {
    precondition(!nums.isEmpty, "nums must not be empty")
    let last = nums[nums.count - 1]
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
    return nums[low]
}

/// Naive solution: scan everything. O(n) time, O(1) space.
public func minimumInRotatedArrayBruteForce(_ nums: [Int]) -> Int {
    precondition(!nums.isEmpty, "nums must not be empty")
    return nums.min()!
}
