import Testing
@testable import Challenges

@Suite("Longest Concatenation of Unique Letters")
struct LongestUniqueConcatenationTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(longestUniqueConcatenation(["sky", "lab", "kite", "mud"]) == 10)
        #expect(longestUniqueConcatenation(["moon", "sun", "star"]) == 4)
        #expect(longestUniqueConcatenation(["aa", "bb"]) == 0)
    }

    @Test("Empty list and empty words")
    func empty() {
        #expect(longestUniqueConcatenation([]) == 0)
        #expect(longestUniqueConcatenation(["", "", "ab"]) == 2)
    }

    @Test("A word with a repeated letter is never usable")
    func repeatedLetterInWord() {
        #expect(longestUniqueConcatenation(["abca", "de"]) == 2)
    }

    @Test("All 26 letters")
    func fullAlphabet() {
        #expect(longestUniqueConcatenation(["abcdefghijklm", "nopqrstuvwxyz", "a"]) == 26)
        #expect(longestUniqueConcatenation(["abcdefghijklmnopqrstuvwxyz"]) == 26)
    }

    @Test("Greedy longest-first isn't enough")
    func greedyFails() {
        // Taking the longest word first ("abcdef", 6) blocks the two that together make 8.
        #expect(longestUniqueConcatenation(["abcdef", "abcg", "dehi"]) == 8)
    }

    @Test("Agrees with checking every subset on random word lists")
    func agreesWithBruteForce() {
        var random = LCG(state: 51)
        let letters = Array("abcdefghijkl")
        for _ in 0..<300 {
            let words = (0..<random.next(0...9)).map { _ in
                String((0..<random.next(1...4)).map { _ in letters[random.next(0...11)] })
            }
            #expect(longestUniqueConcatenation(words) == longestUniqueConcatenationBruteForce(words))
        }
    }
}

/// Small deterministic generator so failures reproduce.
private struct LCG {
    var state: UInt64
    mutating func next(_ range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return range.lowerBound + Int((state >> 33) % UInt64(range.count))
    }
}
