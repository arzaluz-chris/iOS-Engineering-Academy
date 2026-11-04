/// Removes elements from a sorted array, in place, so that each value appears at most twice.
/// The order of the remaining elements doesn't change.
///
/// A reader visits every element; a writer marks where the next kept element goes. A value
/// is kept unless it equals the element two places behind the writer, which in a sorted
/// array means two copies are already kept. O(n) time, O(1) extra space.
public func keepAtMostTwoCopies(_ sorted: inout [Int]) {
    var write = 0
    for read in sorted.indices where write < 2 || sorted[read] != sorted[write - 2] {
        sorted[write] = sorted[read]
        write += 1
    }
    sorted.removeLast(sorted.count - write)
}

/// Naive solution: walk the array and call `remove(at:)` on every third or later copy.
/// Each removal shifts the rest of the array, so it's O(n²) time, O(1) extra space.
public func keepAtMostTwoCopiesBruteForce(_ sorted: inout [Int]) {
    var index = 2
    while index < sorted.count {
        if sorted[index] == sorted[index - 2] {
            sorted.remove(at: index)
        } else {
            index += 1
        }
    }
}
