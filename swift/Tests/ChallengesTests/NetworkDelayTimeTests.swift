import Testing
@testable import Challenges

@Suite("Network Delay Time")
struct NetworkDelayTimeTests {
    @Test("Examples from the problem statement")
    func examples() {
        let links = [(from: 0, to: 1, delay: 4), (from: 0, to: 2, delay: 1), (from: 2, to: 1, delay: 2), (from: 1, to: 3, delay: 5)]
        #expect(signalDelay(nodeCount: 4, links: links, source: 0) == 8)
        #expect(signalDelay(nodeCount: 4, links: links, source: 1) == nil)
    }

    @Test("A single relay needs no time")
    func single() {
        #expect(signalDelay(nodeCount: 1, links: [], source: 0) == 0)
    }

    @Test("Links are one-way")
    func oneWay() {
        #expect(signalDelay(nodeCount: 2, links: [(from: 1, to: 0, delay: 3)], source: 0) == nil)
    }

    @Test("Zero-delay links, duplicate links and cycles")
    func zeroDuplicatesCycles() {
        let links = [
            (from: 0, to: 1, delay: 0), (from: 1, to: 0, delay: 0),
            (from: 1, to: 2, delay: 9), (from: 1, to: 2, delay: 3),
            (from: 2, to: 0, delay: 1),
        ]
        #expect(signalDelay(nodeCount: 3, links: links, source: 0) == 3)
    }

    @Test("The direct link isn't always the fastest")
    func detourIsFaster() {
        let links = [(from: 0, to: 3, delay: 100), (from: 0, to: 1, delay: 1), (from: 1, to: 2, delay: 1), (from: 2, to: 3, delay: 1)]
        #expect(signalDelay(nodeCount: 4, links: links, source: 0) == 3)
    }

    @Test("Agrees with Bellman-Ford on random networks")
    func agreesWithBellmanFord() {
        var generator = TreeChallengeLCG(seed: 81)
        for _ in 0..<300 {
            let count = generator.next(in: 1...9)
            let links = (0..<generator.next(in: 0...(3 * count))).map { _ in
                (from: generator.next(in: 0...(count - 1)),
                 to: generator.next(in: 0...(count - 1)),
                 delay: generator.next(in: 0...20))
            }
            let source = generator.next(in: 0...(count - 1))
            #expect(signalDelay(nodeCount: count, links: links, source: source)
                    == signalDelayBellmanFord(nodeCount: count, links: links, source: source))
        }
    }
}
