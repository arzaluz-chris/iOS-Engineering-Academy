import Testing
@testable import Challenges

@Suite("Valid Palindrome")
struct ValidPalindromeTests {
    @Test("Palindromes", arguments: [
        "A man, a plan, a canal: Panama",
        "Was it a car or a cat I saw?",
        "",
        " ",
        ".,!",
        "a",
        "No 'x' in Nixon",
        "12321",
    ])
    func palindromes(input: String) {
        #expect(isPalindrome(input))
    }

    @Test("Not palindromes", arguments: [
        "race a car",
        "0P",
        "ab",
        "12 3 4 1",
    ])
    func notPalindromes(input: String) {
        #expect(!isPalindrome(input))
    }
}
