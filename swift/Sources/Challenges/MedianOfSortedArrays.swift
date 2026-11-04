/// Returns the median of all the values in two sorted arrays, without merging them.
///
/// Call the shorter array `a`. The median splits the combined values into a left half of
/// `leftSize = (total + 1) / 2` values and a right half. If the left half takes `i` values from
/// `a`, it takes `j = leftSize - i` from `b`, and the split is right when `a[i - 1] <= b[j]` and
/// `b[j - 1] <= a[i]`. The condition `a[i] >= b[j - 1]` is false for small `i` and true from
/// some `i` on, so a boundary binary search over `0...a.count` finds the split.
/// O(log min(m, n)) time, O(1) space.
public func medianOfSortedArrays(_ first: [Int], _ second: [Int]) -> Double {
    let (a, b) = first.count <= second.count ? (first, second) : (second, first)
    let total = a.count + b.count
    precondition(total > 0, "at least one array must have values")
    let leftSize = (total + 1) / 2

    var low = 0
    var high = a.count
    while low < high {
        let mid = low + (high - low) / 2
        if a[mid] >= b[leftSize - mid - 1] {
            high = mid
        } else {
            low = mid + 1
        }
    }

    let i = low
    let j = leftSize - i
    let leftMax = max(i > 0 ? a[i - 1] : Int.min, j > 0 ? b[j - 1] : Int.min)
    if total % 2 == 1 {
        return Double(leftMax)
    }
    let rightMin = min(i < a.count ? a[i] : Int.max, j < b.count ? b[j] : Int.max)
    return (Double(leftMax) + Double(rightMin)) / 2
}

/// Naive solution: merge the two arrays, then read the middle. O(m + n) time and space.
public func medianOfSortedArraysBruteForce(_ first: [Int], _ second: [Int]) -> Double {
    var merged: [Int] = []
    merged.reserveCapacity(first.count + second.count)
    var i = 0
    var j = 0
    while i < first.count || j < second.count {
        if j == second.count || (i < first.count && first[i] <= second[j]) {
            merged.append(first[i])
            i += 1
        } else {
            merged.append(second[j])
            j += 1
        }
    }
    precondition(!merged.isEmpty, "at least one array must have values")
    let middle = merged.count / 2
    if merged.count % 2 == 1 {
        return Double(merged[middle])
    }
    return (Double(merged[middle - 1]) + Double(merged[middle])) / 2
}
