/// Returns every string of `pairs` opening and `pairs` closing parentheses that's balanced,
/// in lexicographic order (`(` sorts before `)`).
///
/// Backtracking that only ever builds valid prefixes: an opener is allowed while fewer than
/// `pairs` have been used, and a closer only while there are more openers than closers so far.
/// Every partial string it builds can be completed, so the work is proportional to the output:
/// O(n · C(n)) time, where C(n) ≈ 4^n / (n^1.5 · √π) is the n-th Catalan number,
/// which is O(4^n / √n). O(n) space besides the output (the current string and the recursion).
public func generateParentheses(_ pairs: Int) -> [String] {
    guard pairs >= 0 else { return [] }
    var results: [String] = []
    var current: [Character] = []

    func extend(opened: Int, closed: Int) {
        if closed == pairs {
            results.append(String(current))
            return
        }
        if opened < pairs {
            current.append("(")
            extend(opened: opened + 1, closed: closed)
            current.removeLast()
        }
        if closed < opened {
            current.append(")")
            extend(opened: opened, closed: closed + 1)
            current.removeLast()
        }
    }

    extend(opened: 0, closed: 0)
    return results
}

/// Naive version: build all 2^(2n) strings of length 2n, in lexicographic order,
/// and keep the balanced ones. O(n · 4^n) time.
public func generateParenthesesBruteForce(_ pairs: Int) -> [String] {
    guard pairs >= 0 else { return [] }
    let length = 2 * pairs
    var results: [String] = []
    for mask in 0..<(1 << length) {
        var characters: [Character] = []
        var balance = 0
        var valid = true
        for position in 0..<length {
            // The highest bit decides the first character, so masks come out in lexicographic order.
            let isCloser = mask & (1 << (length - 1 - position)) != 0
            characters.append(isCloser ? ")" : "(")
            balance += isCloser ? -1 : 1
            if balance < 0 {
                valid = false
                break
            }
        }
        if valid && balance == 0 {
            results.append(String(characters))
        }
    }
    return results
}
