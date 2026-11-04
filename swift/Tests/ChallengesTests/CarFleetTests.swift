import Testing
@testable import Challenges

/// Deterministic pseudo-random numbers (a 64-bit LCG), so a failing case reproduces.
private struct SeededGenerator {
    var state: UInt64
    mutating func next(below bound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
}

@Suite("Car Fleet")
struct CarFleetTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(carFleets(target: 20, positions: [16, 12, 1, 9, 5], speeds: [2, 4, 1, 1, 3]) == 3)
        #expect(carFleets(target: 10, positions: [0, 4], speeds: [3, 1]) == 1)
        #expect(carFleets(target: 100, positions: [0, 2, 4], speeds: [4, 2, 1]) == 1)
    }

    @Test("No cars, and one car")
    func tiny() {
        #expect(carFleets(target: 10, positions: [], speeds: []) == 0)
        #expect(carFleets(target: 10, positions: [3], speeds: [2]) == 1)
    }

    @Test("Catching up exactly at the target counts as one fleet")
    func meetAtTarget() {
        // Both arrive at time 2: (10 - 6) / 2 and (10 - 0) / 5.
        #expect(carFleets(target: 10, positions: [6, 0], speeds: [2, 5]) == 1)
    }

    @Test("Faster cars ahead never get caught")
    func fasterAhead() {
        #expect(carFleets(target: 20, positions: [15, 10, 5], speeds: [5, 3, 1]) == 3)
    }

    @Test("Arrival times that are very close together")
    func closeFractions() {
        // 999_999 / 1_000_000 versus 1_000_000 / 1_000_001: the car behind is slower to arrive.
        #expect(carFleets(target: 1_000_000, positions: [1, 0], speeds: [1_000_000, 1_000_001]) == 2)
    }

    @Test("Random roads agree with the naive version")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 7)
        for _ in 0..<500 {
            let target = 5 + generator.next(below: 40)
            var candidates = Array(0..<target)
            var positions: [Int] = []
            for _ in 0..<generator.next(below: min(10, target)) {
                positions.append(candidates.remove(at: generator.next(below: candidates.count)))
            }
            let speeds = positions.map { _ in 1 + generator.next(below: 6) }
            #expect(
                carFleets(target: target, positions: positions, speeds: speeds)
                    == carFleetsBruteForce(target: target, positions: positions, speeds: speeds),
                "target: \(target), positions: \(positions), speeds: \(speeds)"
            )
        }
    }
}
