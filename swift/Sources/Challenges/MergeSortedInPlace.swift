/// Merges the sorted array `second` into `first`, in place. On entry, `first` holds
/// `firstCount` sorted values followed by `second.count` placeholder slots; on exit it holds
/// all the values, sorted.
///
/// Fills `first` from the back with the larger of the two last unplaced values, so a write
/// never lands on a value that hasn't been read yet. O(n + m) time, O(1) extra space.
public func mergeIntoFirst(_ first: inout [Int], count firstCount: Int, _ second: [Int]) {
    precondition(first.count == firstCount + second.count, "first needs room for second")
    var i = firstCount - 1
    var j = second.count - 1
    var write = first.count - 1
    while j >= 0 {
        if i >= 0 && first[i] > second[j] {
            first[write] = first[i]
            i -= 1
        } else {
            first[write] = second[j]
            j -= 1
        }
        write -= 1
    }
}

/// Naive solution: copy `second` into the slots and sort everything.
/// O((n + m) log(n + m)) time; it ignores that both inputs are already sorted.
public func mergeIntoFirstBySorting(_ first: inout [Int], count firstCount: Int, _ second: [Int]) {
    precondition(first.count == firstCount + second.count, "first needs room for second")
    first.replaceSubrange(firstCount..<first.count, with: second)
    first.sort()
}
