import Testing
@testable import Challenges

@Suite("Isomorphic Strings")
struct IsomorphicStringsTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(isIsomorphic("paper", "title"))
        #expect(isIsomorphic("moon", "deer"))
        #expect(isIsomorphic("moon", "dear") == false)
        #expect(isIsomorphic("ab", "aa") == false)
        #expect(isIsomorphic("aa", "ab") == false)
    }

    @Test("Empty strings and single characters")
    func tiny() {
        #expect(isIsomorphic("", ""))
        #expect(isIsomorphic("x", "y"))
        #expect(isIsomorphic("x", "x"))
    }

    @Test("Different lengths")
    func differentLengths() {
        #expect(isIsomorphic("abc", "ab") == false)
        #expect(isIsomorphic("", "a") == false)
    }

    @Test("A character may map to itself, and the mapping can swap characters")
    func selfAndSwap() {
        #expect(isIsomorphic("abab", "baba"))
        #expect(isIsomorphic("swift", "swift"))
    }

    @Test("Spaces, digits and emoji are characters too")
    func otherCharacters() {
        #expect(isIsomorphic("a b", "1 2"))
        #expect(isIsomorphic("a b", "1 1") == false)
        #expect(isIsomorphic("a b", "1x2"))
        #expect(isIsomorphic("🍎🍎🍐", "xxy"))
        #expect(isIsomorphic("🍎🍐🍎", "xxy") == false)
    }

    @Test("Agrees with the naive solution on random strings")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 6)
        let alphabet: [Character] = ["a", "b", "c", "d"]
        for _ in 0..<2_000 {
            let length = generator.next(below: 7)
            let first = String((0..<length).map { _ in alphabet[generator.next(below: alphabet.count)] })
            let second = String((0..<length).map { _ in alphabet[generator.next(below: alphabet.count)] })
            #expect(isIsomorphic(first, second) == isIsomorphicBruteForce(first, second))
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
