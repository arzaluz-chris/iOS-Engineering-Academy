/// Returns the FizzBuzz lines from 1 to `n`, inclusive.
/// - Multiples of both 3 and 5: "FizzBuzz"
/// - Multiples of 3 only: "Fizz"
/// - Multiples of 5 only: "Buzz"
/// - Everything else: the number as text.
/// For `n < 1` it returns an empty list.
///
/// O(n) time, O(n) space for the result.
public func fizzBuzz(_ n: Int) -> [String] {
    guard n >= 1 else { return [] }
    var result: [String] = []
    result.reserveCapacity(n)
    for i in 1...n {
        let divisibleBy3 = i % 3 == 0
        let divisibleBy5 = i % 5 == 0
        switch (divisibleBy3, divisibleBy5) {
        case (true, true):
            result.append("FizzBuzz")
        case (true, false):
            result.append("Fizz")
        case (false, true):
            result.append("Buzz")
        case (false, false):
            result.append(String(i))
        }
    }
    return result
}
