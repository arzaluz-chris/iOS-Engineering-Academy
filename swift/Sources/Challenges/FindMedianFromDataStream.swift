/// Keeps the median of a stream of integers as they arrive.
///
/// The smaller half lives in a max-heap and the larger half in a min-heap. After every `add`, the
/// lower heap has either the same number of values as the upper one or exactly one more, so the
/// median is the lower heap's top, or the average of both tops.
///
/// - `add`: O(log n) time.
/// - `median`: O(1) time.
/// - O(n) space.
public struct RunningMedian {
    private var lower = MedianHeap(by: >)   // max-heap: its top is the largest of the smaller half
    private var upper = MedianHeap(by: <)   // min-heap: its top is the smallest of the larger half

    public init() {}

    public mutating func add(_ value: Int) {
        if let lowerTop = lower.top, value > lowerTop {
            upper.push(value)
        } else {
            lower.push(value)
        }
        // Rebalance so that lower.count is upper.count or upper.count + 1.
        if lower.count > upper.count + 1 {
            upper.push(lower.pop()!)
        } else if upper.count > lower.count {
            lower.push(upper.pop()!)
        }
    }

    /// The median of everything added so far, or `nil` before the first value.
    public func median() -> Double? {
        guard let lowerTop = lower.top else { return nil }
        if lower.count > upper.count { return Double(lowerTop) }
        return (Double(lowerTop) + Double(upper.top!)) / 2
    }
}

/// A binary heap of `Int` ordered by `comesFirst`: `<` gives a min-heap, `>` a max-heap.
struct MedianHeap {
    private var storage: [Int] = []
    private let comesFirst: (Int, Int) -> Bool

    init(by comesFirst: @escaping (Int, Int) -> Bool) {
        self.comesFirst = comesFirst
    }

    var count: Int { storage.count }
    var top: Int? { storage.first }

    mutating func push(_ value: Int) {
        storage.append(value)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard comesFirst(storage[child], storage[parent]) else { return }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Int? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let removed = storage.removeLast()
        var parent = 0
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var first = parent
            if left < storage.count && comesFirst(storage[left], storage[first]) { first = left }
            if right < storage.count && comesFirst(storage[right], storage[first]) { first = right }
            if first == parent { break }
            storage.swapAt(parent, first)
            parent = first
        }
        return removed
    }
}

/// Naive solution: keep every value in a sorted array. Binary search finds the insertion point in
/// O(log n), but inserting shifts the elements after it: `add` is O(n). `median` is O(1).
public struct RunningMedianSortedArray {
    private var sorted: [Int] = []

    public init() {}

    public mutating func add(_ value: Int) {
        var low = 0
        var high = sorted.count
        while low < high {
            let middle = (low + high) / 2
            if sorted[middle] < value { low = middle + 1 } else { high = middle }
        }
        sorted.insert(value, at: low)
    }

    public func median() -> Double? {
        guard !sorted.isEmpty else { return nil }
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return Double(sorted[middle]) }
        return (Double(sorted[middle - 1]) + Double(sorted[middle])) / 2
    }
}
