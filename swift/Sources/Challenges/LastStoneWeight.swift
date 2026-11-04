/// Smashes the two heaviest stones together until at most one is left, and returns its weight
/// (0 if none is left). Equal stones destroy each other; otherwise the heavier one survives with
/// the difference as its new weight.
///
/// A max-heap keeps the heaviest stone on top. Each round is two pops and at most one push.
/// O(n log n) time, O(n) space.
public func lastStoneWeight(_ stones: [Int]) -> Int {
    var heap = StoneMaxHeap(stones)
    while let heaviest = heap.pop() {
        guard let second = heap.pop() else { return heaviest }
        if heaviest > second {
            heap.push(heaviest - second)
        }
    }
    return 0
}

/// A binary max-heap of `Int` stored in an array: the children of index i are at 2i + 1 and 2i + 2.
struct StoneMaxHeap {
    private var storage: [Int] = []

    /// Builds the heap in O(n) by sifting down every node that has children, from the bottom up.
    init(_ values: [Int]) {
        storage = values
        for index in stride(from: storage.count / 2 - 1, through: 0, by: -1) {
            siftDown(from: index)
        }
    }

    mutating func push(_ value: Int) {
        storage.append(value)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard storage[child] > storage[parent] else { return }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Int? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let top = storage.removeLast()
        siftDown(from: 0)
        return top
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var largest = parent
            if left < storage.count && storage[left] > storage[largest] { largest = left }
            if right < storage.count && storage[right] > storage[largest] { largest = right }
            if largest == parent { return }
            storage.swapAt(parent, largest)
            parent = largest
        }
    }
}

/// Naive solution: sort the whole pile before every round and take the last two.
/// O(n² log n) time, O(n) space.
public func lastStoneWeightBySorting(_ stones: [Int]) -> Int {
    var pile = stones
    while pile.count > 1 {
        pile.sort()
        let heaviest = pile.removeLast()
        let second = pile.removeLast()
        if heaviest > second {
            pile.append(heaviest - second)
        }
    }
    return pile.first ?? 0
}
