import Testing
@testable import Challenges

@Suite("Cheapest Travel Passes")
struct CheapestTravelPassesTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(cheapestPassCost(travelDays: [1, 3, 4, 5, 9, 30], dayPrice: 3, weekPrice: 10, monthPrice: 40) == 16)
        #expect(cheapestPassCost(travelDays: [2, 10, 20], dayPrice: 3, weekPrice: 10, monthPrice: 40) == 9)
        #expect(cheapestPassCost(travelDays: Array(1...20), dayPrice: 3, weekPrice: 10, monthPrice: 25) == 25)
    }

    @Test("No travel days costs nothing")
    func noTravel() {
        #expect(cheapestPassCost(travelDays: [], dayPrice: 3, weekPrice: 10, monthPrice: 40) == 0)
    }

    @Test("One travel day")
    func oneDay() {
        #expect(cheapestPassCost(travelDays: [365], dayPrice: 3, weekPrice: 10, monthPrice: 40) == 3)
        #expect(cheapestPassCost(travelDays: [1], dayPrice: 12, weekPrice: 10, monthPrice: 40) == 10)
    }

    @Test("A longer pass can be cheaper than a shorter one")
    func unusualPrices() {
        #expect(cheapestPassCost(travelDays: [1, 2, 3], dayPrice: 50, weekPrice: 60, monthPrice: 5) == 5)
    }

    @Test("Passes bought late in the year may run past day 365")
    func endOfYear() {
        #expect(cheapestPassCost(travelDays: [360, 362, 365], dayPrice: 4, weekPrice: 10, monthPrice: 40) == 10)
    }

    @Test("Agrees with trying every pass on random trips")
    func agreesWithBruteForce() {
        var generator = TravelPassesLCG(seed: 7)
        for _ in 0..<300 {
            let count = generator.next(below: 11)
            let days = Set((0..<count).map { _ in 1 + generator.next(below: 90) }).sorted()
            let day = 1 + generator.next(below: 10)
            let week = 1 + generator.next(below: 30)
            let month = 1 + generator.next(below: 80)
            #expect(
                cheapestPassCost(travelDays: days, dayPrice: day, weekPrice: week, monthPrice: month)
                    == cheapestPassCostBruteForce(travelDays: days, dayPrice: day, weekPrice: week, monthPrice: month),
                "\(days) \(day) \(week) \(month)"
            )
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct TravelPassesLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
