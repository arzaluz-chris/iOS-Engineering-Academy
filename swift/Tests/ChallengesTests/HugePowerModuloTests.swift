import Testing
@testable import Challenges

@Suite("Power with a Huge Exponent")
struct HugePowerModuloTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(hugePowerModulo(3, exponentDigits: [4], modulus: 50) == 31)
        #expect(hugePowerModulo(2, exponentDigits: [1, 0], modulus: 1_000) == 24)
        #expect(hugePowerModulo(7, exponentDigits: [0], modulus: 13) == 1)
    }

    @Test("Modulus 1 always gives 0")
    func modulusOne() {
        #expect(hugePowerModulo(5, exponentDigits: [0], modulus: 1) == 0)
        #expect(hugePowerModulo(5, exponentDigits: [9, 9], modulus: 1) == 0)
    }

    @Test("Base 0, base 1, and a base that's a multiple of the modulus")
    func specialBases() {
        #expect(hugePowerModulo(0, exponentDigits: [0], modulus: 7) == 1)
        #expect(hugePowerModulo(0, exponentDigits: [1, 2], modulus: 7) == 0)
        #expect(hugePowerModulo(1, exponentDigits: Array(repeating: 9, count: 500), modulus: 7) == 1)
        #expect(hugePowerModulo(14, exponentDigits: [3], modulus: 7) == 0)
    }

    @Test("Leading zeros in the exponent don't change it")
    func leadingZeros() {
        #expect(hugePowerModulo(3, exponentDigits: [0, 0, 4], modulus: 50) == 31)
    }

    @Test("Base larger than the modulus and a large prime modulus")
    func largeValues() {
        #expect(hugePowerModulo(1_000_000_000_000, exponentDigits: [2], modulus: 1_000_000_007)
            == (1_000_000_000_000 % 1_000_000_007) * (1_000_000_000_000 % 1_000_000_007) % 1_000_000_007)
        // Fermat: a^(p-1) ≡ 1 (mod p) for a prime p that doesn't divide a.
        #expect(hugePowerModulo(2, exponentDigits: [1, 0, 0, 0, 0, 0, 0, 0, 0, 6], modulus: 1_000_000_007) == 1)
    }

    @Test("A 2,000-digit exponent: 10^2000 mod φ(m) checks it against Euler's theorem")
    func hugeExponent() {
        // 1 followed by 2,000 zeros is a multiple of 4 = φ(5), and gcd(2, 5) = 1, so 2^E ≡ 1 (mod 5).
        let digits = [1] + Array(repeating: 0, count: 2_000)
        #expect(hugePowerModulo(2, exponentDigits: digits, modulus: 5) == 1)
        // 3^E mod 10: the last digit of powers of 3 cycles 3, 9, 7, 1, and 4 divides E.
        #expect(hugePowerModulo(3, exponentDigits: digits, modulus: 10) == 1)
    }

    @Test("Agrees with repeated multiplication on random small exponents")
    func agreesWithBruteForce() {
        var random = LCG(state: 63)
        for _ in 0..<500 {
            let base = random.next(0...1_000)
            let exponent = random.next(0...3_000)
            let digits = String(exponent).map { $0.wholeNumberValue! }
            let modulus = random.next(1...100_000)
            #expect(hugePowerModulo(base, exponentDigits: digits, modulus: modulus)
                == hugePowerModuloBruteForce(base, exponentDigits: digits, modulus: modulus))
        }
    }
}

/// Small deterministic generator so failures reproduce.
private struct LCG {
    var state: UInt64
    mutating func next(_ range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return range.lowerBound + Int((state >> 33) % UInt64(range.count))
    }
}
