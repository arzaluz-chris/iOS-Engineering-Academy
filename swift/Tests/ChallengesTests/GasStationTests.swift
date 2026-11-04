import Testing
@testable import Challenges

@Suite("Gas Station")
struct GasStationTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(startingChargerIndex(charge: [1, 5, 2, 3], cost: [2, 2, 4, 1]) == 1)
        #expect(startingChargerIndex(charge: [2, 2], cost: [3, 2]) == nil)
        #expect(startingChargerIndex(charge: [0, 4, 0], cost: [1, 1, 2]) == 1)
    }

    @Test("A single stop")
    func single() {
        #expect(startingChargerIndex(charge: [3], cost: [3]) == 0)
        #expect(startingChargerIndex(charge: [0], cost: [1]) == nil)
    }

    @Test("No stops")
    func empty() {
        #expect(startingChargerIndex(charge: [], cost: []) == nil)
    }

    @Test("When every stop works, the smallest index wins")
    func severalStarts() {
        #expect(startingChargerIndex(charge: [2, 2, 2], cost: [1, 1, 1]) == 0)
        #expect(startingChargerIndex(charge: [0, 0], cost: [0, 0]) == 0)
    }

    @Test("Exactly enough energy, with the answer at the last stop")
    func lastStop() {
        #expect(startingChargerIndex(charge: [1, 1, 4], cost: [2, 2, 2]) == 2)
    }

    @Test("Agrees with simulating every start on random loops")
    func agreesWithBruteForce() {
        var generator = GasStationLCG(seed: 11)
        for _ in 0..<500 {
            let count = generator.next(below: 9)
            let charge = (0..<count).map { _ in generator.next(below: 6) }
            let cost = (0..<count).map { _ in generator.next(below: 6) }
            #expect(startingChargerIndex(charge: charge, cost: cost) == startingChargerIndexBruteForce(charge: charge, cost: cost),
                    "\(charge) \(cost)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct GasStationLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
