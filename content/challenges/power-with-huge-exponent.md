---
id: power-with-huge-exponent
title: Power with a Huge Exponent
difficulty: medium
order: 62
patterns: [Fast exponentiation, Modular arithmetic, Divide and conquer]
prerequisites: [m18-l01, m18-l06]
summary: Compute base^E modulo m when E has thousands of digits. Fast exponentiation, one decimal digit of the exponent at a time.
solutionFile: HugePowerModulo.swift
testFile: HugePowerModuloTests.swift
starter: |
  func hugePowerModulo(_ base: Int, exponentDigits: [Int], modulus: Int) -> Int {
      // Your solution
      return 0
  }
time: O(L) for L digits
space: O(1)
edgeCases:
  - Exponent 0, which gives 1 (and 0 for modulus 1)
  - Modulus 1, which always gives 0
  - Base 0, base 1, and a base that's a multiple of the modulus
  - Leading zeros in the exponent's digits
askInterviewer:
  - How large can the modulus be? That decides whether a product of two remainders fits in Int.
  - What's 0^0 here? (1, the usual convention in this context.)
  - Are the exponent digits most significant first?
  - Can the base be negative?
hints:
  - "You can't turn the digits into an Int. But you can read a number one digit at a time: E = 10 · E' + d."
  - What is base^(10 · E' + d) in terms of base^E'?
  - Reduce modulo m after every multiplication, and use the lesson's fast power for the small exponents 10 and d.
followUps:
  - What's the largest modulus for which this code can't overflow, and how would you support a bigger one?
  - When the modulus is prime, how does Fermat's little theorem let you shrink the exponent first?
  - How would you compute the n-th Fibonacci number modulo m for n around 10^18? (Fast exponentiation of a 2 × 2 matrix.)
rubric:
  - I explained why the exponent can't be converted to an integer and why multiplying E times is hopeless.
  - I used base^(10E' + d) = (base^E')^10 · base^d to process one digit at a time.
  - I reduced modulo m after every multiplication and stated the bound that prevents overflow.
  - I gave O(L) time with a constant number of multiplications per digit.
codeStatus: tested
---

A security exercise asks you to check a value of the form `base^E mod m`, where the exponent `E` is enormous: it arrives as an array of its decimal digits, most significant first, and can have thousands of them. Write `hugePowerModulo(_:exponentDigits:modulus:)` that returns `base^E mod modulus`, with `0^0` taken as 1.

```swift
hugePowerModulo(3, exponentDigits: [4], modulus: 50)        // 31, because 3^4 = 81
hugePowerModulo(2, exponentDigits: [1, 0], modulus: 1_000)  // 24, because 2^10 = 1024
hugePowerModulo(7, exponentDigits: [0], modulus: 13)        // 1
```

**Constraints:** `0 ≤ base ≤ 10^18`; `1 ≤ exponentDigits.count ≤ 2,000`, each digit in `0...9`, leading zeros allowed; `1 ≤ modulus ≤ 3,037,000,499`.

<!-- reveal -->

## First approach

The lesson's `power` computes xⁿ with O(log n) multiplications by halving the exponent. Here the exponent doesn't fit in any integer type, so you can't halve it directly. But you can read it the way you'd read any number, one digit at a time: if E' is the number formed by the digits so far and d is the next digit, the new exponent is 10 · E' + d, and base^(10·E' + d) = (base^E')¹⁰ · base^d. Two small powers per digit, each done modulo m.

## Naive solution

Turn the digits into an `Int` and multiply that many times:

```swift
func hugePowerModulo(_ base: Int, exponentDigits: [Int], modulus: Int) -> Int {
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
```

## Problems with the naive solution

Two separate failures. First, `exponent` overflows as soon as there are more than 18 or 19 digits, and Swift traps on overflow. Second, even an exponent that fits, say 10^18, would mean 10^18 multiplications: decades of computing. The naive loop only works for small exponents, which is why the tests use it only for those.

## Optimized solution

Keep `result = base^E' mod m` for the digits read so far. For each new digit `d`, replace it with `result^10 · base^d mod m`. Both small powers use fast exponentiation by the bits of the exponent, the iterative version of the lesson's halving `power`, and every product is reduced modulo m right away so it never overflows.

## Line by line

- `hugePowerModuloSmall(_ base:_ exponent:_ modulus:)`: the bit-by-bit fast power. `if remaining & 1 == 1` multiplies the current square into the result when the lowest bit is set; `square = square * square % modulus` moves to the next power of two; `remaining >>= 1` drops the bit.
- `var result = 1 % modulus`: 1 for any modulus except 1, where everything is 0. Writing `1 % modulus` handles both without a branch.
- `precondition(modulus >= 1 && modulus <= 3_037_000_499, ...)`: every remainder is below the modulus, so a product of two is below 3,037,000,499², which is about 9.22 · 10^18 and still fits in `Int`.
- `let reducedBase = base % modulus`: reduce once up front, so the base can be as large as 10^18.
- `for digit in exponentDigits`: most significant first, like reading the number aloud.
- `result = hugePowerModuloSmall(result, 10, modulus) * hugePowerModuloSmall(reducedBase, digit, modulus) % modulus`: (base^E')¹⁰ · base^d, reduced. Each call does one squaring per bit of its exponent plus one multiplication per set bit, which for 10 and for any digit from 0 to 9 is at most 6. So a digit costs at most 13 multiplications, and the total is O(L).
- Leading zeros need no special case: a 0 digit at the start computes 1¹⁰ · base⁰ = 1, the same as an empty exponent.

## Common mistakes

- Reducing only at the end, after products have already overflowed.
- Writing `var result = 1`, which returns 1 instead of 0 for modulus 1 when the exponent is 0.
- Processing the digits from least significant first with the formula for most significant first. It works from the right too, but the recurrence is different: keep a running `base^(10^i)` and multiply it in `d` times.
- Calling the recursive halving `power` with both halves computed separately, which makes it O(n) instead of O(log n), the trap the lesson warns about.

## Variation

**Pow(x, n) with a negative exponent:** for a `Double` base and an `Int` exponent, compute x^|n| by squaring and take the reciprocal if n is negative. The trap is `n = Int.min`: `-n` overflows, so work with the magnitude as a `UInt` or halve before negating.
