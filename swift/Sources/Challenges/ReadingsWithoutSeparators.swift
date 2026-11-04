/// Counts the ways to split a string of ASCII digits into a list of integers, each between 1 and
/// `maxValue`, written without leading zeros. The count is returned modulo 1,000,000,007.
///
/// ways[i] is the number of ways to split the suffix that starts at i. A suffix that starts with
/// "0" can't be split (no number starts with 0). Otherwise the first number takes digits i...end
/// for every end that keeps it ≤ maxValue, and the rest is ways[end + 1]. The inner loop stops as
/// soon as the number gets too big, so it runs at most d + 1 times, d being the digits in maxValue.
/// O(n · d) time, O(n) space.
public func countReadings(_ digits: String, maxValue: Int) -> Int {
    let modulus = 1_000_000_007
    let values = digits.map { $0.wholeNumberValue! }
    let count = values.count
    var ways = Array(repeating: 0, count: count + 1)
    ways[count] = 1   // the empty suffix: one way, the empty list
    for start in stride(from: count - 1, through: 0, by: -1) where values[start] != 0 {
        var number = 0
        var total = 0
        for end in start..<count {
            number = number * 10 + values[end]
            if number > maxValue { break }
            total = (total + ways[end + 1]) % modulus
        }
        ways[start] = total
    }
    return ways[0]
}

/// Naive solution: plain recursion over every possible first number. Exponential time,
/// O(n) stack depth. The tests keep inputs short, so the count doesn't need the modulus.
public func countReadingsBruteForce(_ digits: String, maxValue: Int) -> Int {
    let characters = Array(digits)
    func ways(from start: Int) -> Int {
        guard start < characters.count else { return 1 }
        guard characters[start] != "0" else { return 0 }
        var total = 0
        for end in start..<characters.count {
            guard let number = Int(String(characters[start...end])), number <= maxValue else { break }
            total += ways(from: end + 1)
        }
        return total
    }
    return ways(from: 0)
}
