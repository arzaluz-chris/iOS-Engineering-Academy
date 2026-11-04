import Testing
@testable import Challenges

@Suite("Minimum Window Substring")
struct MinimumWindowSubstringTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(smallestCoveringWindow("XAYBZCABX", covering: "ABC") == "CAB")
        #expect(smallestCoveringWindow("banana", covering: "aan") == "ana")
        #expect(smallestCoveringWindow("swift", covering: "z") == "")
    }

    @Test("Repeated required characters need repeated copies")
    func repeats() {
        #expect(smallestCoveringWindow("ab", covering: "aa") == "")
        #expect(smallestCoveringWindow("abaa", covering: "aa") == "aa")
    }

    @Test("Empty inputs")
    func empty() {
        #expect(smallestCoveringWindow("", covering: "a") == "")
        #expect(smallestCoveringWindow("abc", covering: "") == "")
    }

    @Test("The whole text is the answer")
    func wholeText() {
        #expect(smallestCoveringWindow("abc", covering: "cba") == "abc")
    }

    @Test("Ties go to the leftmost window")
    func ties() {
        #expect(smallestCoveringWindow("abxba", covering: "ab") == "ab")
    }

    @Test("Case matters, and any character can be required")
    func characters() {
        #expect(smallestCoveringWindow("aA bB", covering: "A ") == "A ")
        #expect(smallestCoveringWindow("x🙂yy🙂", covering: "🙂y") == "🙂y")
    }

    @Test("Agrees with the naive solution on random strings")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 20)
        let alphabet: [Character] = ["a", "b", "c"]
        func randomWord(maxLength: Int) -> String {
            String((0..<generator.next(below: maxLength)).map { _ in alphabet[generator.next(below: alphabet.count)] })
        }
        for _ in 0..<1_000 {
            let required = randomWord(maxLength: 4)
            let text = randomWord(maxLength: 12)
            #expect(smallestCoveringWindow(text, covering: required) == smallestCoveringWindowBruteForce(text, covering: required))
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
