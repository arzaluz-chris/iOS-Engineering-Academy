import Testing
@testable import Challenges

@Suite("Valid Parentheses")
struct ValidParenthesesTests {
    @Test("Válidas", arguments: ["()", "()[]{}", "{[]}", "", "([]{})", "(((())))"])
    func validas(input: String) {
        #expect(isValidParentheses(input))
    }

    @Test("Inválidas", arguments: ["(]", "([)]", "(", ")", "((", "){", "(()", "())"])
    func invalidas(input: String) {
        #expect(!isValidParentheses(input))
    }

    @Test("Un carácter que no es paréntesis invalida la cadena")
    func otrosCaracteres() {
        #expect(!isValidParentheses("(a)"))
    }
}
