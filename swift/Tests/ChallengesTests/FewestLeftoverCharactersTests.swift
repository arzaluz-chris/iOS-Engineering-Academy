import Testing
@testable import Challenges

@Suite("Fewest Leftover Characters")
struct FewestLeftoverCharactersTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(fewestLeftoverCharacters("swiftxui", words: ["swift", "ui"]) == 1)
        #expect(fewestLeftoverCharacters("darkmodeon", words: ["dark", "mode", "darkmode", "on"]) == 0)
        #expect(fewestLeftoverCharacters("abc", words: ["xyz"]) == 3)
    }

    @Test("Empty text and empty dictionary")
    func empty() {
        #expect(fewestLeftoverCharacters("", words: ["a"]) == 0)
        #expect(fewestLeftoverCharacters("hello", words: []) == 5)
    }

    @Test("Greedy longest match isn't always best")
    func greedyFails() {
        // Taking "abcd" first leaves "ef" over; "ab" + "cdef" leaves nothing.
        #expect(fewestLeftoverCharacters("abcdef", words: ["abcd", "ab", "cdef"]) == 0)
    }

    @Test("Overlapping words: a character can belong to only one word")
    func overlapping() {
        #expect(fewestLeftoverCharacters("catsand", words: ["cats", "sand"]) == 3)
    }

    @Test("Words can repeat")
    func repeats() {
        #expect(fewestLeftoverCharacters("lalalaX", words: ["la"]) == 1)
    }

    @Test("Agrees with the naive recursion on random inputs")
    func agreesWithBruteForce() {
        var generator = LeftoverLCG(seed: 99)
        let letters: [Character] = ["a", "b", "c"]
        func randomWord(maxLength: Int) -> String {
            String((0..<(1 + generator.next(below: maxLength))).map { _ in letters[generator.next(below: 3)] })
        }
        for _ in 0..<300 {
            let text = generator.next(below: 4) == 0 ? "" : randomWord(maxLength: 12)
            let words = Set((0..<generator.next(below: 6)).map { _ in randomWord(maxLength: 4) })
            #expect(
                fewestLeftoverCharacters(text, words: words) == fewestLeftoverCharactersBruteForce(text, words: words),
                "\(text) \(words)"
            )
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct LeftoverLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
