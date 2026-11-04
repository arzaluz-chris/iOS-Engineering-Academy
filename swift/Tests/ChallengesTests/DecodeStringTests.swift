import Testing
@testable import Challenges

/// Deterministic pseudo-random numbers (a 64-bit LCG), so a failing case reproduces.
private struct SeededGenerator {
    var state: UInt64
    mutating func next(below bound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
}

/// Builds a random valid encoding up to `depth` levels deep.
private func randomEncoding(_ generator: inout SeededGenerator, depth: Int) -> String {
    var result = ""
    for _ in 0..<(1 + generator.next(below: 3)) {
        if depth > 0 && generator.next(below: 2) == 0 {
            let count = 1 + generator.next(below: 12)
            result += "\(count)[" + randomEncoding(&generator, depth: depth - 1) + "]"
        } else {
            let letters = Array("abcxyz")
            result.append(letters[generator.next(below: letters.count)])
        }
    }
    return result
}

@Suite("Decode String")
struct DecodeStringTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(decodeString("3[ha]") == "hahaha")
        #expect(decodeString("2[a3[b]]") == "abbbabbb")
        #expect(decodeString("ab2[go]") == "abgogo")
        #expect(decodeString("2[x]3[yz]") == "xxyzyzyz")
    }

    @Test("Empty string and plain text")
    func noGroups() {
        #expect(decodeString("") == "")
        #expect(decodeString("hello") == "hello")
    }

    @Test("Counts with more than one digit")
    func multiDigitCounts() {
        #expect(decodeString("12[a]") == String(repeating: "a", count: 12))
        #expect(decodeString("10[2[b]]") == String(repeating: "b", count: 20))
    }

    @Test("Text after a closing bracket goes back to the enclosing level")
    func textAfterGroup() {
        #expect(decodeString("2[a2[b]c]d") == "abbcabbcd")
    }

    @Test("Deep nesting")
    func deepNesting() {
        #expect(decodeString("2[2[2[2[z]]]]") == String(repeating: "z", count: 16))
    }

    @Test("Random encodings agree with the naive expansion")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 2024)
        for _ in 0..<300 {
            let encoded = randomEncoding(&generator, depth: 3)
            #expect(decodeString(encoded) == decodeStringBruteForce(encoded), "input: \(encoded)")
        }
    }
}
