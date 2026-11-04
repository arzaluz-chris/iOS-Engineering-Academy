/// A stack of integers that also reports its smallest element in O(1).
///
/// Each entry stores the pushed value together with the minimum of everything at or below it,
/// so the minimum after a pop is already sitting in the new top entry.
/// Every operation is O(1) (push amortized, because it appends to an Array). O(n) space.
public struct MinStack {
    private var entries: [(value: Int, minimum: Int)] = []

    public init() {}

    public var isEmpty: Bool { entries.isEmpty }

    /// The top value, or `nil` if the stack is empty.
    public func top() -> Int? {
        entries.last?.value
    }

    /// The smallest value in the stack, or `nil` if the stack is empty.
    public func minimum() -> Int? {
        entries.last?.minimum
    }

    public mutating func push(_ value: Int) {
        let minimumSoFar = min(value, entries.last?.minimum ?? value)
        entries.append((value: value, minimum: minimumSoFar))
    }

    /// Removes and returns the top value, or returns `nil` if the stack is empty.
    @discardableResult
    public mutating func pop() -> Int? {
        entries.popLast()?.value
    }
}

/// Naive version: a plain stack that scans every element to find the minimum.
/// push, pop and top are O(1); `minimum` is O(n).
public struct MinStackBruteForce {
    private var values: [Int] = []

    public init() {}

    public var isEmpty: Bool { values.isEmpty }
    public func top() -> Int? {
        values.last
    }

    public func minimum() -> Int? {
        values.min()
    }

    public mutating func push(_ value: Int) {
        values.append(value)
    }

    @discardableResult
    public mutating func pop() -> Int? {
        values.popLast()
    }
}
