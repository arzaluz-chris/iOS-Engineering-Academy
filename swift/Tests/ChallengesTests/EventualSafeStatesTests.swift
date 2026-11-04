import Testing
@testable import Challenges

@Suite("Eventual Safe States")
struct EventualSafeStatesTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(eventualSafeStates([[1, 2], [3], [5], [0], [5], [], []]) == [2, 4, 5, 6])
        #expect(eventualSafeStates([[1], [2], []]) == [0, 1, 2])
    }

    @Test("Empty graph")
    func empty() {
        #expect(eventualSafeStates([]) == [])
    }

    @Test("A self-loop is a cycle")
    func selfLoop() {
        #expect(eventualSafeStates([[0]]) == [])
        #expect(eventualSafeStates([[0, 1], []]) == [1])
    }

    @Test("One move into a cycle is enough to be unsafe")
    func oneBadMove() {
        // 0 can go to the dead end 1 or into the cycle 2 <-> 3.
        #expect(eventualSafeStates([[1, 2], [], [3], [2]]) == [1])
    }

    @Test("Pointing at an unsafe state from outside the cycle")
    func downstreamOfCycle() {
        // 3 -> 0, and 0 <-> 1 is a cycle. 2 is a dead end.
        #expect(eventualSafeStates([[1], [0], [], [0, 2]]) == [2])
    }

    @Test("Duplicate moves to the same state")
    func duplicateEdges() {
        #expect(eventualSafeStates([[1, 1], []]) == [0, 1])
    }

    @Test("Agrees with the per-state DFS on random graphs")
    func agreesWithBruteForce() {
        var generator = TreeChallengeLCG(seed: 80)
        for _ in 0..<300 {
            let count = generator.next(in: 0...10)
            let graph = (0..<count).map { _ in
                (0..<generator.next(in: 0...2)).map { _ in generator.next(in: 0...(count - 1)) }
            }
            #expect(eventualSafeStates(graph) == eventualSafeStatesBruteForce(graph))
        }
    }
}
