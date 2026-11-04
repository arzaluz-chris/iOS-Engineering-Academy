import Testing
@testable import Challenges

@Suite("Group Shifted Strings")
struct GroupShiftedStringsTests {
    @Test("Example from the problem statement")
    func example() {
        let words = ["ace", "bdf", "hal", "zbd", "ibm", "x", "a", "yza"]
        #expect(groupShiftedWords(words) == [["ace", "bdf", "zbd"], ["hal", "ibm"], ["x", "a"], ["yza"]])
    }

    @Test("Wrapping from z to a")
    func wrapping() {
        #expect(groupShiftedWords(["az", "ba", "za"]) == [["az", "ba"], ["za"]])
        #expect(groupShiftedWords(["xyz", "abc"]) == [["xyz", "abc"]])
    }

    @Test("Empty input, empty words and duplicates")
    func edgeCases() {
        #expect(groupShiftedWords([]) == [])
        #expect(groupShiftedWords(["", "a", ""]) == [["", ""], ["a"]])
        #expect(groupShiftedWords(["ab", "ab"]) == [["ab", "ab"]])
    }

    @Test("Same pattern but different lengths stay apart")
    func lengths() {
        #expect(groupShiftedWords(["ab", "abc", "bc"]) == [["ab", "bc"], ["abc"]])
    }

    @Test("Agrees with the naive solution on random words")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 7)
        let letters = Array("abcxyz".utf8)
        for _ in 0..<300 {
            let words = (0..<generator.next(below: 12)).map { _ in
                let length = generator.next(below: 4)
                return String(decoding: (0..<length).map { _ in letters[generator.next(below: letters.count)] }, as: UTF8.self)
            }
            #expect(groupShiftedWords(words) == groupShiftedWordsBruteForce(words))
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
