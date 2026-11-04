import Testing
@testable import Challenges

@Suite("Longest Palindromic Subsequence")
struct LongestPalindromicSubsequenceTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(longestPalindromicSubsequence("character") == 5)
        #expect(longestPalindromicSubsequence("banana") == 5)
        #expect(longestPalindromicSubsequence("swift") == 1)
    }

    @Test("Empty, one and two characters")
    func short() {
        #expect(longestPalindromicSubsequence("") == 0)
        #expect(longestPalindromicSubsequence("x") == 1)
        #expect(longestPalindromicSubsequence("aa") == 2)
        #expect(longestPalindromicSubsequence("ab") == 1)
    }

    @Test("A string that's already a palindrome")
    func alreadyPalindrome() {
        #expect(longestPalindromicSubsequence("racecar") == 7)
        #expect(longestPalindromicSubsequence("abba") == 4)
    }

    @Test("All the same character")
    func sameCharacter() {
        #expect(longestPalindromicSubsequence(String(repeating: "z", count: 300)) == 300)
    }

    @Test("Characters are compared as Swift Characters")
    func characters() {
        #expect(longestPalindromicSubsequence("é1é") == 3)
        #expect(longestPalindromicSubsequence("Aa") == 1)
    }

    @Test("Agrees with checking every subset on random strings")
    func agreesWithBruteForce() {
        var generator = PalindromicLCG(seed: 31)
        let letters: [Character] = ["a", "b", "c"]
        for _ in 0..<300 {
            let text = String((0..<generator.next(below: 13)).map { _ in letters[generator.next(below: 3)] })
            #expect(longestPalindromicSubsequence(text) == longestPalindromicSubsequenceBruteForce(text), "\(text)")
        }
    }
}

/// Deterministic generator so failures reproduce.
private struct PalindromicLCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
