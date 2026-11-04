import Testing
@testable import Challenges

@Suite("Readings Without Separators")
struct ReadingsWithoutSeparatorsTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(countReadings("1225", maxValue: 26) == 5)
        #expect(countReadings("123", maxValue: 1000) == 4)
        #expect(countReadings("1000", maxValue: 100) == 0)
    }

    @Test("Zeros can't start a number")
    func zeros() {
        #expect(countReadings("07", maxValue: 100) == 0)
        #expect(countReadings("1000", maxValue: 1000) == 1)
        #expect(countReadings("101", maxValue: 10) == 1)
        #expect(countReadings("0", maxValue: 9) == 0)
    }

    @Test("A digit bigger than maxValue")
    func tooBig() {
        #expect(countReadings("9", maxValue: 5) == 0)
        #expect(countReadings("5", maxValue: 5) == 1)
    }

    @Test("The largest maxValue")
    func largeMax() {
        #expect(countReadings("1000000000", maxValue: 1_000_000_000) == 1)
        #expect(countReadings("1000000001", maxValue: 1_000_000_000) == 1)   // 100000000 then 1
        #expect(countReadings("1000000000", maxValue: 999_999_999) == 0)
    }

    @Test("Long inputs are counted modulo 1,000,000,007")
    func modulo() {
        // With maxValue 11, a run of n ones splits like climbing n stairs by 1 or 2: Fibonacci.
        var previous = 1
        var current = 1
        for _ in 2...5_000 {
            (previous, current) = (current, (previous + current) % 1_000_000_007)
        }
        #expect(countReadings(String(repeating: "1", count: 5_000), maxValue: 11) == current)
    }

    @Test("Agrees with the naive recursion on random inputs")
    func agreesWithBruteForce() {
        var generator = ReadingsLCG(seed: 8)
        let maxValues = [1, 9, 10, 26, 99, 100, 255, 1000, 65_535]
        for _ in 0..<400 {
            let digits = String((0..<(1 + generator.next(below: 12))).map { _ in
                Character(String(generator.next(below: 4) == 0 ? 0 : generator.next(below: 10)))
            })
            let maxValue = maxValues[generator.next(below: maxValues.count)]
            #expect(countReadings(digits, maxValue: maxValue) == countReadingsBruteForce(digits, maxValue: maxValue),
                    "\(digits) \(maxValue)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct ReadingsLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
