import Testing
@testable import Challenges

@Suite("Ad Slots in a Loop")
struct AdSlotsInALoopTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(bestLoopRevenue([6, 1, 2, 5]) == 8)
        #expect(bestLoopRevenue([3, 6, 3]) == 6)
        #expect(bestLoopRevenue([2, 9, 4, 1, 7]) == 16)
    }

    @Test("Empty, one and two slots")
    func smallCarousels() {
        #expect(bestLoopRevenue([]) == 0)
        #expect(bestLoopRevenue([8]) == 8)
        #expect(bestLoopRevenue([5, 7]) == 7)
    }

    @Test("First and last are both the best but can't be taken together")
    func firstAndLast() {
        #expect(bestLoopRevenue([10, 1, 1, 10]) == 11)
    }

    @Test("All zeros")
    func zeros() {
        #expect(bestLoopRevenue([0, 0, 0, 0]) == 0)
    }

    @Test("Agrees with checking every subset on random carousels")
    func agreesWithBruteForce() {
        var generator = AdSlotsLCG(seed: 42)
        for _ in 0..<400 {
            let count = generator.next(below: 17)
            let revenue = (0..<count).map { _ in generator.next(below: 50) }
            #expect(bestLoopRevenue(revenue) == bestLoopRevenueBruteForce(revenue), "\(revenue)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct AdSlotsLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
