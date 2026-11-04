/// Inserts `newRange` into a sorted list of half-open ranges that don't overlap or touch,
/// merging it with every range it overlaps or touches, and returns the result, still sorted
/// and with no overlaps or touching ranges.
///
/// One pass in three phases: copy the ranges that end before `newRange` starts; absorb every
/// range that starts at or before the merged range's end, widening it with `min` and `max`;
/// copy the rest. O(n) time, O(n) space for the result.
public func insertRange(_ ranges: [Range<Int>], _ newRange: Range<Int>) -> [Range<Int>] {
    var result: [Range<Int>] = []
    var index = 0

    while index < ranges.count && ranges[index].upperBound < newRange.lowerBound {
        result.append(ranges[index])
        index += 1
    }

    var lower = newRange.lowerBound
    var upper = newRange.upperBound
    while index < ranges.count && ranges[index].lowerBound <= upper {
        lower = min(lower, ranges[index].lowerBound)
        upper = max(upper, ranges[index].upperBound)
        index += 1
    }
    result.append(lower..<upper)

    while index < ranges.count {
        result.append(ranges[index])
        index += 1
    }
    return result
}

/// Naive version: append the new range, sort everything by start, and merge from scratch,
/// joining ranges that overlap or touch. O(n log n) time, O(n) space.
public func insertRangeBruteForce(_ ranges: [Range<Int>], _ newRange: Range<Int>) -> [Range<Int>] {
    let sorted = (ranges + [newRange]).sorted { $0.lowerBound < $1.lowerBound }
    var merged: [Range<Int>] = []
    for range in sorted {
        if let last = merged.last, range.lowerBound <= last.upperBound {
            merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
        } else {
            merged.append(range)
        }
    }
    return merged
}
