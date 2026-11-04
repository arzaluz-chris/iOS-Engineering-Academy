import Testing
@testable import Challenges

@Suite("Generate Parentheses")
struct GenerateParenthesesTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(generateParentheses(1) == ["()"])
        #expect(generateParentheses(2) == ["(())", "()()"])
        #expect(generateParentheses(3) == ["((()))", "(()())", "(())()", "()(())", "()()()"])
    }

    @Test("Zero pairs gives one empty string")
    func zeroPairs() {
        #expect(generateParentheses(0) == [""])
    }

    @Test("The counts are the Catalan numbers", arguments: [
        (4, 14), (5, 42), (6, 132), (7, 429), (8, 1430),
    ])
    func catalanCounts(pairs: Int, expected: Int) {
        let results = generateParentheses(pairs)
        #expect(results.count == expected)
        #expect(Set(results).count == expected)
    }

    @Test("Same output, in the same order, as the naive filter", arguments: 0...8)
    func agreesWithBruteForce(pairs: Int) {
        #expect(generateParentheses(pairs) == generateParenthesesBruteForce(pairs))
    }

    @Test("Every result is balanced, has the right length, and comes out sorted")
    func resultsAreValid() {
        let results = generateParentheses(6)
        #expect(results == results.sorted())
        for string in results {
            #expect(string.count == 12)
            var balance = 0
            for character in string {
                balance += character == "(" ? 1 : -1
                #expect(balance >= 0)
            }
            #expect(balance == 0)
        }
    }
}
