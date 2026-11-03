/// Returns whether the parentheses `()`, brackets `[]` and braces `{}` in `s` are balanced
/// and properly nested. Any other character makes the string invalid.
///
/// Every opener is pushed onto a stack; every closer must match the most recent pending opener.
/// O(n) time, O(n) space in the worst case (only openers).
public func isValidParentheses(_ s: String) -> Bool {
    let openerFor: [Character: Character] = [")": "(", "]": "[", "}": "{"]
    let openers: Set<Character> = ["(", "[", "{"]
    var stack: [Character] = []

    for character in s {
        if openers.contains(character) {
            stack.append(character)
        } else if let expectedOpener = openerFor[character] {
            guard stack.popLast() == expectedOpener else { return false }
        } else {
            return false
        }
    }
    return stack.isEmpty
}
