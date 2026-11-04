import Testing
@testable import Challenges

@Suite("Palindrome Partitioning")
struct PalindromePartitionsTests {
    private func normalized(_ partitions: [[String]]) -> [[String]] {
        partitions.sorted { $0.lexicographicallyPrecedes($1) }
    }

    @Test("Examples from the problem statement")
    func examples() {
        #expect(palindromePartitions("noon") == [["n", "o", "o", "n"], ["n", "oo", "n"], ["noon"]])
        #expect(palindromePartitions("abc") == [["a", "b", "c"]])
    }

    @Test("Empty string has one partition with no pieces")
    func empty() {
        #expect(palindromePartitions("") == [[]])
    }

    @Test("Single character")
    func single() {
        #expect(palindromePartitions("x") == [["x"]])
    }

    @Test("One repeated letter has 2^(n-1) partitions")
    func repeatedLetter() {
        #expect(palindromePartitions("aaaa").count == 8)
        #expect(palindromePartitions(String(repeating: "z", count: 12)).count == 2_048)
    }

    @Test("Odd-length palindromes in the middle")
    func oddLength() {
        #expect(normalized(palindromePartitions("abab"))
            == normalized([["a", "b", "a", "b"], ["a", "bab"], ["aba", "b"]]))
    }

    @Test("Agrees with trying every set of cuts on random strings")
    func agreesWithBruteForce() {
        var random = LCG(state: 56)
        let letters: [Character] = ["a", "b", "c"]
        for _ in 0..<300 {
            let text = String((0..<random.next(1...10)).map { _ in letters[random.next(0...2)] })
            #expect(normalized(palindromePartitions(text)) == normalized(palindromePartitionsBruteForce(text)))
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
