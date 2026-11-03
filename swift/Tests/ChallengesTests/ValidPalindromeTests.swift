import Testing
@testable import Challenges

@Suite("Valid Palindrome")
struct ValidPalindromeTests {
    @Test("Palíndromos", arguments: [
        "A man, a plan, a canal: Panama",
        "Anita lava la tina",
        "",
        " ",
        ".,!",
        "a",
        "No 'x' in Nixon",
        "12321",
    ])
    func palindromos(input: String) {
        #expect(isPalindrome(input))
    }

    @Test("No palíndromos", arguments: [
        "race a car",
        "0P",
        "ab",
        "12 3 4 1",
    ])
    func noPalindromos(input: String) {
        #expect(!isPalindrome(input))
    }
}
