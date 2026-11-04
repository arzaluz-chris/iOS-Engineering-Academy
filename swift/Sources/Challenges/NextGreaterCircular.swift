/// For each position in a circular array, returns the first value strictly greater than it
/// found by walking forward and wrapping around to the start, or -1 if there's none.
///
/// A decreasing monotonic stack of indexes, run over the array twice. The first lap resolves
/// everything it can and leaves the unresolved indexes waiting; the second lap lets them see
/// the elements before them. Indexes are pushed only during the first lap, so each one is
/// pushed once and popped at most once: O(n) time, O(n) space.
public func nextGreaterCircular(_ values: [Int]) -> [Int] {
    let count = values.count
    var answers = Array(repeating: -1, count: count)
    var waiting: [Int] = []

    for step in 0..<(2 * count) {
        let index = step % count
        let value = values[index]
        while let last = waiting.last, values[last] < value {
            answers[last] = value
            waiting.removeLast()
        }
        if step < count {
            waiting.append(index)
        }
    }
    return answers
}

/// Naive version: from each position, walk forward up to n - 1 steps with wraparound.
/// O(n²) time, O(1) extra space besides the result.
public func nextGreaterCircularBruteForce(_ values: [Int]) -> [Int] {
    let count = values.count
    var answers = Array(repeating: -1, count: count)
    for index in 0..<count {
        for offset in 1..<max(count, 1) {
            let candidate = values[(index + offset) % count]
            if candidate > values[index] {
                answers[index] = candidate
                break
            }
        }
    }
    return answers
}
