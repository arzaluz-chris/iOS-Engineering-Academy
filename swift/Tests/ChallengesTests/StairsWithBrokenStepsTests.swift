import Testing
@testable import Challenges

@Suite("Stairs With Broken Steps")
struct StairsWithBrokenStepsTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(countClimbs(steps: 4, broken: []) == 5)
        #expect(countClimbs(steps: 6, broken: [3]) == 4)
        #expect(countClimbs(steps: 5, broken: [2, 3]) == 0)
    }

    @Test("Zero steps: one way, already at the top")
    func zeroSteps() {
        #expect(countClimbs(steps: 0, broken: []) == 1)
        #expect(countClimbs(steps: 0, broken: [1, 2]) == 1)
    }

    @Test("A broken top step means no way up")
    func brokenTop() {
        #expect(countClimbs(steps: 3, broken: [3]) == 0)
        #expect(countClimbs(steps: 1, broken: [1]) == 0)
    }

    @Test("Broken step 1 forces a 2-step start")
    func brokenFirst() {
        #expect(countClimbs(steps: 2, broken: [1]) == 1)
        #expect(countClimbs(steps: 4, broken: [1]) == 2)
    }

    @Test("Numbers outside 1...n are ignored")
    func outOfRange() {
        #expect(countClimbs(steps: 4, broken: [0, -3, 9]) == 5)
    }

    @Test("The largest n in the constraints doesn't overflow")
    func largest() {
        #expect(countClimbs(steps: 90, broken: []) == 4_660_046_610_375_530_309)
    }

    @Test("Agrees with the naive recursion on every small case")
    func agreesWithBruteForce() {
        for n in 0...14 {
            // Every subset of steps 1...n as the broken set.
            for mask in 0..<(1 << n) {
                let broken = Set((1...max(n, 1)).filter { mask & (1 << ($0 - 1)) != 0 })
                #expect(countClimbs(steps: n, broken: broken) == countClimbsBruteForce(steps: n, broken: broken))
            }
        }
    }
}
