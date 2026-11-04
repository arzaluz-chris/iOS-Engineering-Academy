import Testing
@testable import Challenges

@Suite("Rotting Oranges")
struct RottingOrangesTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(minutesUntilAllRotten([
            [2, 1, 1],
            [1, 1, 0],
            [0, 1, 1],
        ]) == 4)
        #expect(minutesUntilAllRotten([
            [2, 1, 0],
            [0, 0, 1],
        ]) == nil)
        #expect(minutesUntilAllRotten([[0, 2, 0]]) == 0)
    }

    @Test("Several rotten fruit spread at the same time")
    func multipleSources() {
        #expect(minutesUntilAllRotten([[2, 1, 1, 1, 1, 1, 2]]) == 3)
    }

    @Test("No fresh fruit at all, including an empty crate")
    func nothingFresh() {
        #expect(minutesUntilAllRotten([]) == 0)
        #expect(minutesUntilAllRotten([[0, 0], [0, 0]]) == 0)
    }

    @Test("Fresh fruit but nothing rotten")
    func nothingRotten() {
        #expect(minutesUntilAllRotten([[1]]) == nil)
    }

    @Test("Diagonals don't count")
    func noDiagonals() {
        #expect(minutesUntilAllRotten([[2, 0], [0, 1]]) == nil)
    }

    @Test("Agrees with the minute-by-minute simulation on random crates")
    func agreesWithSimulation() {
        var generator = TreeChallengeLCG(seed: 78)
        for _ in 0..<300 {
            let rows = generator.next(in: 1...7)
            let columns = generator.next(in: 1...7)
            let grid = (0..<rows).map { _ in
                (0..<columns).map { _ -> Int in
                    let roll = generator.next(in: 0...9)
                    return roll < 2 ? 0 : (roll < 9 ? 1 : 2)
                }
            }
            #expect(minutesUntilAllRotten(grid) == minutesUntilAllRottenBySimulation(grid))
        }
    }
}
