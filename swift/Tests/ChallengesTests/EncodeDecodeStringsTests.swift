import Testing
@testable import Challenges

@Suite("Encode and Decode Strings")
struct EncodeDecodeStringsTests {
    @Test("Round trip", arguments: [
        ["swift", "is", "fun"],
        [],
        [""],
        ["", ""],
        ["a#b", "#", "##3#"],
        ["12#hello", "3", "007"],
        ["café", "🇯🇵", "e\u{301}"],
        ["line\nbreak", "tab\tstop", " "],
        [String(repeating: "x", count: 1_000), "y"],
    ])
    func roundTrip(strings: [String]) {
        #expect(decodeStrings(encodeStrings(strings)) == strings)
    }

    @Test("The empty list and a list with one empty string encode differently")
    func emptyVersusEmptyString() {
        #expect(encodeStrings([]) != encodeStrings([""]))
    }

    @Test("Format from the problem statement's example")
    func format() {
        #expect(encodeStrings(["hi", "", "a#b"]) == "2#hi0#3#a#b")
    }

    @Test("Round trip on random strings full of digits and #")
    func randomRoundTrip() {
        var generator = SeededGenerator(seed: 24)
        let alphabet: [Character] = ["#", "1", "2", "0", "a", "é", "🙂", " "]
        for _ in 0..<500 {
            let strings = (0..<generator.next(below: 6)).map { _ in
                String((0..<generator.next(below: 15)).map { _ in alphabet[generator.next(below: alphabet.count)] })
            }
            #expect(decodeStrings(encodeStrings(strings)) == strings)
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
