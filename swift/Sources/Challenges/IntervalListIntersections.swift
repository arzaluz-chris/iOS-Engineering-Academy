/// Returns the time ranges that appear in both lists. Each list is sorted and its ranges are
/// half-open, non-empty and don't overlap or touch each other.
///
/// Two pointers, one per list. The current pair overlaps exactly when the later start is before
/// the earlier end, and then that's their intersection. Whichever range ends first can't overlap
/// anything else in the other list, so that pointer moves on.
/// O(n + m) time, O(1) extra space besides the result.
public func commonFreeTime(_ first: [Range<Int>], _ second: [Range<Int>]) -> [Range<Int>] {
    var result: [Range<Int>] = []
    var i = 0
    var j = 0
    while i < first.count && j < second.count {
        let start = max(first[i].lowerBound, second[j].lowerBound)
        let end = min(first[i].upperBound, second[j].upperBound)
        if start < end {
            result.append(start..<end)
        }
        if first[i].upperBound < second[j].upperBound {
            i += 1
        } else {
            j += 1
        }
    }
    return result
}

/// Naive version: intersect every pair with `clamped(to:)`, keep the non-empty results,
/// and sort them. O(n · m) time plus the sort.
public func commonFreeTimeBruteForce(_ first: [Range<Int>], _ second: [Range<Int>]) -> [Range<Int>] {
    var result: [Range<Int>] = []
    for a in first {
        for b in second {
            let overlap = a.clamped(to: b)
            if !overlap.isEmpty {
                result.append(overlap)
            }
        }
    }
    return result.sorted { $0.lowerBound < $1.lowerBound }
}
