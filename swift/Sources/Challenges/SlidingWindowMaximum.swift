/// Returns the maximum of every window of `k` consecutive values, in order:
/// `values.count - k + 1` results. Returns `[]` if `k` is less than 1 or greater than the count.
///
/// A monotonic deque of indexes whose values decrease from front to back. A new value first
/// removes from the back every index whose value is less than or equal to it (they can never be
/// a maximum again), then joins at the back. The front is the current window's maximum; it's
/// dropped when it slides out of the window. The deque is an Array with a head index, so removing
/// from the front doesn't shift anything. Each index enters once and leaves once:
/// O(n) time, O(n) space for the index array (the live part never holds more than k).
public func slidingWindowMaximum(_ values: [Int], _ k: Int) -> [Int] {
    guard k >= 1, k <= values.count else { return [] }
    var deque: [Int] = []
    var head = 0
    var maximums: [Int] = []
    maximums.reserveCapacity(values.count - k + 1)

    for (index, value) in values.enumerated() {
        while deque.count > head, let last = deque.last, values[last] <= value {
            deque.removeLast()
        }
        deque.append(index)
        if deque[head] <= index - k {
            head += 1
        }
        if index >= k - 1 {
            maximums.append(values[deque[head]])
        }
    }
    return maximums
}

/// Naive version: compute the maximum of each window from scratch. O(n · k) time.
public func slidingWindowMaximumBruteForce(_ values: [Int], _ k: Int) -> [Int] {
    guard k >= 1, k <= values.count else { return [] }
    var maximums: [Int] = []
    for start in 0...(values.count - k) {
        maximums.append(values[start..<(start + k)].max() ?? 0)
    }
    return maximums
}
