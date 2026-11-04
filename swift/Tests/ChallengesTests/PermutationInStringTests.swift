import Testing
@testable import Challenges

@Suite("Permutation in String")
struct PermutationInStringTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(containsRearrangement(of: "tea", in: "breakfast") == false)
        #expect(containsRearrangement(of: "tea", in: "neatly"))
        #expect(containsRearrangement(of: "ab", in: "eidboaoo") == false)
    }

    @Test("Empty pattern and pattern longer than the text")
    func lengths() {
        #expect(containsRearrangement(of: "", in: "abc"))
        #expect(containsRearrangement(of: "", in: ""))
        #expect(containsRearrangement(of: "abcd", in: "abc") == false)
    }

    @Test("The match is the whole text, the start or the end")
    func positions() {
        #expect(containsRearrangement(of: "cab", in: "abc"))
        #expect(containsRearrangement(of: "ba", in: "abxyz"))
        #expect(containsRearrangement(of: "zy", in: "abxyz"))
    }

    @Test("Repeated letters must match in count")
    func counts() {
        #expect(containsRearrangement(of: "aab", in: "abba") == false)
        #expect(containsRearrangement(of: "aab", in: "cbaac"))
    }

    @Test("Agrees with the naive solution on random strings")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 19)
        let letters = Array("abc".utf8)
        func randomWord(maxLength: Int) -> String {
            String(decoding: (0..<generator.next(below: maxLength)).map { _ in letters[generator.next(below: letters.count)] }, as: UTF8.self)
        }
        for _ in 0..<1_000 {
            let pattern = randomWord(maxLength: 4)
            let text = randomWord(maxLength: 10)
            #expect(containsRearrangement(of: pattern, in: text) == containsRearrangementBruteForce(of: pattern, in: text))
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
