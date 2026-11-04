import Testing
@testable import Challenges

@Suite("Best Time to Buy and Sell Stock II")
struct StockManyTradesTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(totalGainFromTrades([8, 3, 6, 4, 9, 10]) == 9)
        #expect(totalGainFromTrades([1, 2, 3, 4]) == 3)
        #expect(totalGainFromTrades([9, 7, 4, 1]) == 0)
    }

    @Test("Empty and one-day histories")
    func tiny() {
        #expect(totalGainFromTrades([]) == 0)
        #expect(totalGainFromTrades([5]) == 0)
    }

    @Test("Flat prices gain nothing")
    func flat() {
        #expect(totalGainFromTrades([4, 4, 4]) == 0)
    }

    @Test("Alternating prices")
    func zigzag() {
        #expect(totalGainFromTrades([1, 5, 1, 5, 1, 5]) == 12)
    }

    @Test("Agrees with trying every sequence of trades")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 16)
        for _ in 0..<300 {
            let prices = (0..<generator.next(below: 9)).map { _ in generator.next(below: 10) }
            #expect(totalGainFromTrades(prices) == totalGainFromTradesBruteForce(prices))
        }
    }
}

/// Small deterministic generator (a linear congruential generator) so failures reproduce.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// A value in `0..<bound`.
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
