import Testing
@testable import Challenges

@Suite("Longest Repeating Character Replacement")
struct LongestRepeatingCharacterReplacementTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(longestUniformRun("RGRRBR", repaints: 1) == 4)
        #expect(longestUniformRun("RGRRBR", repaints: 2) == 6)
        #expect(longestUniformRun("RGBY", repaints: 0) == 1)
    }

    @Test("Empty string")
    func empty() {
        #expect(longestUniformRun("", repaints: 3) == 0)
    }

    @Test("More repaints than tiles")
    func generous() {
        #expect(longestUniformRun("ABC", repaints: 5) == 3)
    }

    @Test("Already uniform")
    func uniform() {
        #expect(longestUniformRun("GGGG", repaints: 0) == 4)
    }

    @Test("The best run is at the end")
    func atTheEnd() {
        #expect(longestUniformRun("ABCDDDD", repaints: 1) == 5)
    }

    @Test("Agrees with the naive solution on random rows")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 18)
        let letters = Array("ABC".utf8)
        for _ in 0..<1_000 {
            let tiles = String(decoding: (0..<generator.next(below: 15)).map { _ in letters[generator.next(below: letters.count)] }, as: UTF8.self)
            let k = generator.next(below: 4)
            #expect(longestUniformRun(tiles, repaints: k) == longestUniformRunBruteForce(tiles, repaints: k))
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
