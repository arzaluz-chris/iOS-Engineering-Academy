import Testing
@testable import Challenges

@Suite("Wildcard Matching")
struct WildcardMatchingTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(wildcardMatches("IMG_0042.HEIC", pattern: "IMG_????.HEIC"))
        #expect(!wildcardMatches("report.pdf", pattern: "*.png"))
        #expect(wildcardMatches("backup-2026-11.zip", pattern: "backup-*.zip"))
        #expect(!wildcardMatches("IMG_42.HEIC", pattern: "IMG_????.HEIC"))
    }

    @Test("Empty text and empty pattern")
    func empty() {
        #expect(wildcardMatches("", pattern: ""))
        #expect(wildcardMatches("", pattern: "*"))
        #expect(wildcardMatches("", pattern: "***"))
        #expect(!wildcardMatches("", pattern: "?"))
        #expect(!wildcardMatches("abc", pattern: ""))
    }

    @Test("A star matches nothing, one character or many")
    func stars() {
        #expect(wildcardMatches("ab", pattern: "a*b"))
        #expect(wildcardMatches("axb", pattern: "a*b"))
        #expect(wildcardMatches("axxxxb", pattern: "a*b"))
        #expect(wildcardMatches("anything", pattern: "*"))
        #expect(wildcardMatches("ab", pattern: "a**b"))
    }

    @Test("The whole text must match, not a prefix")
    func wholeText() {
        #expect(!wildcardMatches("photo.jpgx", pattern: "*.jpg"))
        #expect(!wildcardMatches("xphoto", pattern: "photo*"))
    }

    @Test("Question marks need exactly one character each")
    func questionMarks() {
        #expect(wildcardMatches("ab", pattern: "*?*?*"))
        #expect(!wildcardMatches("a", pattern: "*?*?*"))
    }

    @Test("A star that must not swallow too much")
    func backtracking() {
        #expect(wildcardMatches("aaab", pattern: "a*a*b"))
        #expect(wildcardMatches("abcde", pattern: "*c?e"))
        #expect(!wildcardMatches("abcd", pattern: "*c?e"))
    }

    @Test("Agrees with the naive recursion on random inputs")
    func agreesWithBruteForce() {
        var generator = WildcardLCG(seed: 1234)
        let textLetters: [Character] = ["a", "b"]
        let patternLetters: [Character] = ["a", "b", "?", "*"]
        for _ in 0..<500 {
            let text = String((0..<generator.next(below: 9)).map { _ in textLetters[generator.next(below: 2)] })
            let pattern = String((0..<generator.next(below: 7)).map { _ in patternLetters[generator.next(below: 4)] })
            #expect(wildcardMatches(text, pattern: pattern) == wildcardMatchesBruteForce(text, pattern: pattern),
                    "\(text) \(pattern)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct WildcardLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
