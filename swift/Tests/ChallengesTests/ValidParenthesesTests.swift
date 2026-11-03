import Testing
@testable import Challenges

@Suite("Valid Parentheses")
struct ValidParenthesesTests {
    @Test("Valid", arguments: ["()", "()[]{}", "{[]}", "", "([]{})", "(((())))"])
    func valid(input: String) {
        #expect(isValidParentheses(input))
    }

    @Test("Invalid", arguments: ["(]", "([)]", "(", ")", "((", "){", "(()", "())"])
    func invalid(input: String) {
        #expect(!isValidParentheses(input))
    }

    @Test("A non-bracket character makes the string invalid")
    func otherCharacters() {
        #expect(!isValidParentheses("(a)"))
    }
}
