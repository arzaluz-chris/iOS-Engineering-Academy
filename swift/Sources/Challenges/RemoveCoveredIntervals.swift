/// Counts the ranges left after removing every range that's covered by a different range in
/// the list. `a` is covered by `b` when `b.lowerBound <= a.lowerBound` and
/// `a.upperBound <= b.upperBound`. Assumes the ranges are distinct.
///
/// Sorts by start ascending and, for equal starts, by end descending, so that any range that
/// could cover another comes before it. Then a range is covered exactly when some earlier range
/// ends at or after its end, which a running maximum of the ends answers in O(1).
/// O(n log n) time for the sort, O(n) space for the sorted copy.
public func uncoveredRangeCount(_ ranges: [Range<Int>]) -> Int {
    let sorted = ranges.sorted {
        $0.lowerBound != $1.lowerBound ? $0.lowerBound < $1.lowerBound : $0.upperBound > $1.upperBound
    }
    var kept = 0
    var furthestEnd = Int.min
    for range in sorted where range.upperBound > furthestEnd {
        kept += 1
        furthestEnd = range.upperBound
    }
    return kept
}

/// Naive version: for each range, check every other range to see if it covers it. O(n²) time.
public func uncoveredRangeCountBruteForce(_ ranges: [Range<Int>]) -> Int {
    var kept = 0
    for (i, a) in ranges.enumerated() {
        let covered = ranges.indices.contains { j in
            j != i && ranges[j].lowerBound <= a.lowerBound && a.upperBound <= ranges[j].upperBound
        }
        if !covered {
            kept += 1
        }
    }
    return kept
}
