import Testing
@testable import Challenges

@Suite("Sort Characters by Frequency")
struct SortCharactersByFrequencyTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(sortedByFrequency("banana") == "aaannb")
        #expect(sortedByFrequency("tree") == "eetr")
        #expect(sortedByFrequency("Aabb") == "bbAa")
    }

    @Test("Empty string and a single character")
    func tiny() {
        #expect(sortedByFrequency("") == "")
        #expect(sortedByFrequency("z") == "z")
    }

    @Test("All characters distinct keeps the original order")
    func allDistinct() {
        #expect(sortedByFrequency("swift") == "swift")
    }

    @Test("Spaces, digits and emoji count like letters")
    func otherCharacters() {
        #expect(sortedByFrequency("a 1 1") == "  11a")
        #expect(sortedByFrequency("🐱a🐱") == "🐱🐱a")
    }

    @Test("Agrees with the naive solution on random strings")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 8)
        let alphabet: [Character] = ["a", "b", "c", "d", "e", " "]
        for _ in 0..<1_000 {
            let text = String((0..<generator.next(below: 15)).map { _ in alphabet[generator.next(below: alphabet.count)] })
            #expect(sortedByFrequency(text) == sortedByFrequencyBruteForce(text))
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
