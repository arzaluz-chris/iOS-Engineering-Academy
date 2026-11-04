/// Sorts `colors` in place, where every value is a color from 1 to `colorCount`.
///
/// Divide and conquer on the colors, not on the positions ("rainbow sort"). Split the color
/// range in half at `middle`, partition the slice so every color `<= middle` comes first (one
/// two-pointer pass, like quicksort's partition), then sort each side with its half of the colors.
/// The color range halves at each level, so there are about log₂ k levels, and each level
/// touches every element once: O(n log k) time, O(log k) space for the recursion.
public func sortKColors(_ colors: inout [Int], colorCount: Int) {
    precondition(colorCount >= 1, "there must be at least one color")

    func sort(_ low: Int, _ high: Int, _ firstColor: Int, _ lastColor: Int) {
        if high - low < 2 || firstColor >= lastColor {
            return
        }
        let middle = firstColor + (lastColor - firstColor) / 2
        var left = low
        var right = high - 1
        while left <= right {
            if colors[left] <= middle {
                left += 1
            } else {
                colors.swapAt(left, right)
                right -= 1
            }
        }
        sort(low, left, firstColor, middle)
        sort(left, high, middle + 1, lastColor)
    }

    sort(0, colors.count, 1, colorCount)
}

/// Naive solution: one pass per color, each pulling that color forward with swaps.
/// O(n · k) time, O(1) space.
public func sortKColorsBruteForce(_ colors: inout [Int], colorCount: Int) {
    var placed = 0
    for color in 1...max(colorCount, 1) {
        for index in placed..<colors.count where colors[index] == color {
            colors.swapAt(index, placed)
            placed += 1
        }
    }
}
