/// Returns whether `s` is a palindrome, counting only letters and digits and ignoring case.
///
/// Two indices move from the ends toward the middle, skipping anything that isn't a letter or digit.
/// O(n) time; O(n) space for the `Array` copy (indexing a `String` directly
/// by integer position isn't O(1) in Swift).
public func isPalindrome(_ s: String) -> Bool {
    let characters = Array(s.lowercased())
    var left = 0
    var right = characters.count - 1
    while left < right {
        if !isAlphanumeric(characters[left]) {
            left += 1
            continue
        }
        if !isAlphanumeric(characters[right]) {
            right -= 1
            continue
        }
        if characters[left] != characters[right] {
            return false
        }
        left += 1
        right -= 1
    }
    return true
}

private func isAlphanumeric(_ c: Character) -> Bool {
    c.isLetter || c.isNumber
}
