import Testing
@testable import Challenges

@Suite("Signs for a Target Balance")
struct SignsForATargetBalanceTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(countSignAssignments([2, 3, 5], target: 0) == 2)
        #expect(countSignAssignments([1, 2, 3, 4], target: 2) == 2)
        #expect(countSignAssignments([4, 6], target: 3) == 0)
    }

    @Test("Zeros double the count")
    func zeros() {
        #expect(countSignAssignments([0, 0, 1], target: 1) == 4)
        #expect(countSignAssignments([0], target: 0) == 2)
    }

    @Test("No amounts: only a target of 0 works")
    func empty() {
        #expect(countSignAssignments([], target: 0) == 1)
        #expect(countSignAssignments([], target: 5) == 0)
    }

    @Test("Targets beyond the total, and negative targets")
    func outOfReach() {
        #expect(countSignAssignments([1, 2], target: 4) == 0)
        #expect(countSignAssignments([1, 2], target: -4) == 0)
        #expect(countSignAssignments([1, 2, 3, 4], target: -2) == 2)
        #expect(countSignAssignments([5, 5], target: -10) == 1)
    }

    @Test("Wrong parity gives 0")
    func parity() {
        #expect(countSignAssignments([1, 1, 1], target: 2) == 0)
    }

    @Test("Agrees with trying every sign on random inputs")
    func agreesWithBruteForce() {
        var generator = SignsLCG(seed: 77)
        for _ in 0..<400 {
            let amounts = (0..<generator.next(below: 13)).map { _ in generator.next(below: 7) }
            let target = generator.next(below: 31) - 15
            #expect(countSignAssignments(amounts, target: target) == countSignAssignmentsBruteForce(amounts, target: target),
                    "\(amounts) \(target)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct SignsLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
