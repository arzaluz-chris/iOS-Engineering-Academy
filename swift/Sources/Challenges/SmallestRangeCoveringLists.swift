/// Returns the smallest range `a...b` that contains at least one number from each of the sorted
/// lists. "Smallest" means the smallest `b - a`; ties go to the range with the smaller `a`.
/// Returns `nil` if there are no lists or any list is empty.
///
/// A min-heap holds one cursor per list, so the heap's top is the smallest current front, and a
/// variable tracks the largest front. Together they form a range that covers every list. The only
/// way to find a narrower one is to advance the list that has the smallest front. Stop when that
/// list runs out. O(N log k) time for N numbers in k lists, O(k) space.
public func smallestRangeCoveringLists(_ lists: [[Int]]) -> ClosedRange<Int>? {
    guard !lists.isEmpty, lists.allSatisfy({ !$0.isEmpty }) else { return nil }

    var heap = RangeCursorHeap()
    var largestFront = Int.min
    for (list, values) in lists.enumerated() {
        heap.push(RangeCursor(value: values[0], list: list, index: 0))
        largestFront = max(largestFront, values[0])
    }

    var best = heap.top!.value...largestFront
    while let smallest = heap.pop() {
        if largestFront - smallest.value < best.upperBound - best.lowerBound {
            best = smallest.value...largestFront
        }
        let nextIndex = smallest.index + 1
        guard nextIndex < lists[smallest.list].count else { break }
        let nextValue = lists[smallest.list][nextIndex]
        heap.push(RangeCursor(value: nextValue, list: smallest.list, index: nextIndex))
        largestFront = max(largestFront, nextValue)
    }
    return best
}

/// The current front of one list: its value, which list, and the position in it.
struct RangeCursor {
    let value: Int
    let list: Int
    let index: Int
}

/// A min-heap of cursors ordered by value.
struct RangeCursorHeap {
    private var storage: [RangeCursor] = []

    var top: RangeCursor? { storage.first }

    mutating func push(_ cursor: RangeCursor) {
        storage.append(cursor)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard storage[child].value < storage[parent].value else { return }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> RangeCursor? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let removed = storage.removeLast()
        var parent = 0
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var smallest = parent
            if left < storage.count && storage[left].value < storage[smallest].value { smallest = left }
            if right < storage.count && storage[right].value < storage[smallest].value { smallest = right }
            if smallest == parent { break }
            storage.swapAt(parent, smallest)
            parent = smallest
        }
        return removed
    }
}

/// Naive solution: try every number as the start `a`. For each list, binary search for its first
/// number that's at least `a`; the range has to reach the largest of those. O(N · k · log L) time
/// for N numbers, k lists and lists of length up to L; O(1) extra space.
public func smallestRangeCoveringListsByStart(_ lists: [[Int]]) -> ClosedRange<Int>? {
    guard !lists.isEmpty, lists.allSatisfy({ !$0.isEmpty }) else { return nil }

    func firstAtLeast(_ target: Int, in values: [Int]) -> Int? {
        var low = 0
        var high = values.count
        while low < high {
            let middle = (low + high) / 2
            if values[middle] < target { low = middle + 1 } else { high = middle }
        }
        return low < values.count ? values[low] : nil
    }

    var best: ClosedRange<Int>?
    for start in lists.joined() {
        var end = start
        var coversAll = true
        for values in lists {
            guard let reach = firstAtLeast(start, in: values) else {
                coversAll = false
                break
            }
            end = max(end, reach)
        }
        guard coversAll else { continue }
        if let current = best {
            let width = end - start
            let bestWidth = current.upperBound - current.lowerBound
            if width < bestWidth || (width == bestWidth && start < current.lowerBound) {
                best = start...end
            }
        } else {
            best = start...end
        }
    }
    return best
}
