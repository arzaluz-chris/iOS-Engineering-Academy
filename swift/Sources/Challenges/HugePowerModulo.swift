/// Returns `base` raised to `exponent`, modulo `modulus`, with O(log exponent) multiplications.
///
/// Fast exponentiation by the bits of the exponent: square the base each round and multiply it
/// into the result when the lowest bit is 1. Every product is reduced right away, so with
/// `modulus <= 3_037_000_499` no product of two remainders overflows `Int`.
func hugePowerModuloSmall(_ base: Int, _ exponent: Int, _ modulus: Int) -> Int {
    var result = 1 % modulus
    var square = base % modulus
    var remaining = exponent
    while remaining > 0 {
        if remaining & 1 == 1 {
            result = result * square % modulus
        }
        square = square * square % modulus
        remaining >>= 1
    }
    return result
}

/// Returns `base ^ E mod modulus`, where the exponent E is given as its decimal digits, most
/// significant first, and can be far too large for any integer type.
///
/// Read the digits left to right, the way you'd build the number: if E' is the exponent read so
/// far and d the next digit, then base^(10·E' + d) = (base^E')^10 · base^d. So each digit costs
/// one fast power to the 10th and one to the d-th, both reduced modulo `modulus`.
/// O(L) time for L digits (at most 13 multiplications per digit), O(1) space.
public func hugePowerModulo(_ base: Int, exponentDigits: [Int], modulus: Int) -> Int {
    precondition(base >= 0, "base must be non-negative")
    precondition(modulus >= 1 && modulus <= 3_037_000_499, "modulus must be in 1...3_037_000_499")
    precondition(exponentDigits.allSatisfy { (0...9).contains($0) }, "digits must be 0 through 9")
    let reducedBase = base % modulus
    var result = 1 % modulus
    for digit in exponentDigits {
        result = hugePowerModuloSmall(result, 10, modulus) * hugePowerModuloSmall(reducedBase, digit, modulus) % modulus
    }
    return result
}

/// Naive solution: turn the digits into an Int and multiply `exponent` times.
/// O(E) multiplications, and it only works while E fits in an Int.
public func hugePowerModuloBruteForce(_ base: Int, exponentDigits: [Int], modulus: Int) -> Int {
    var exponent = 0
    for digit in exponentDigits {
        exponent = exponent * 10 + digit
    }
    var result = 1 % modulus
    for _ in 0..<exponent {
        result = result * (base % modulus) % modulus
    }
    return result
}
