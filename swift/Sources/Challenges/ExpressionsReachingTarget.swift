/// Returns every expression you can make by putting `+`, `-`, `*` or nothing between the digits
/// of `digits` (keeping their order) that evaluates to `target` with the usual precedence
/// (`*` before `+` and `-`). Operands can't have leading zeros: "05" isn't allowed, "0" is.
///
/// Backtracking over where the next operand ends and which operator comes before it. The state
/// is the value so far and the last term added (`last`), so `*` can be applied without
/// re-parsing: replacing `value` by `value - last + last * operand` undoes the last addition and
/// redoes it multiplied. O(n · 4^n) time (4 choices at each of the n - 1 gaps, and an O(n)
/// string to build at each leaf), O(n) space besides the output.
public func expressionsReachingTarget(_ digits: String, target: Int) -> [String] {
    let characters = Array(digits)
    precondition(characters.allSatisfy { $0.isASCII && $0.isNumber }, "digits must be 0-9")
    guard !characters.isEmpty else { return [] }

    var results: [String] = []
    var expression = ""

    func explore(from start: Int, value: Int, last: Int) {
        if start == characters.count {
            if value == target {
                results.append(expression)
            }
            return
        }
        let lengthBefore = expression.count
        var operand = 0
        for end in start..<characters.count {
            if end > start && characters[start] == "0" {
                break
            }
            operand = operand * 10 + characters[end].wholeNumberValue!
            let text = String(characters[start...end])
            if start == 0 {
                expression = text
                explore(from: end + 1, value: operand, last: operand)
            } else {
                expression += "+" + text
                explore(from: end + 1, value: value + operand, last: operand)
                expression.removeLast(expression.count - lengthBefore)

                expression += "-" + text
                explore(from: end + 1, value: value - operand, last: -operand)
                expression.removeLast(expression.count - lengthBefore)

                expression += "*" + text
                explore(from: end + 1, value: value - last + last * operand, last: last * operand)
            }
            expression.removeLast(expression.count - lengthBefore)
        }
    }

    explore(from: 0, value: 0, last: 0)
    return results
}

/// Naive solution: write out every one of the 4^(n-1) expressions, then evaluate each one with
/// a small precedence-aware evaluator. O(n · 4^n) time like the backtracking, but it can't
/// skip operands with leading zeros early, and it parses every expression twice.
public func expressionsReachingTargetBruteForce(_ digits: String, target: Int) -> [String] {
    let characters = Array(digits)
    guard !characters.isEmpty else { return [] }
    let operators: [String] = ["", "+", "-", "*"]
    var results: [String] = []
    var choice = Array(repeating: 0, count: characters.count - 1)

    while true {
        var text = String(characters[0])
        for gap in choice.indices {
            text += operators[choice[gap]] + String(characters[gap + 1])
        }
        if let value = expressionsReachingTargetEvaluate(text), value == target {
            results.append(text)
        }
        // Next combination of operators, like counting in base 4.
        var gap = choice.count - 1
        while gap >= 0 && choice[gap] == 3 {
            choice[gap] = 0
            gap -= 1
        }
        if gap < 0 {
            break
        }
        choice[gap] += 1
    }
    return results
}

/// Evaluates an expression of non-negative integers with `+`, `-` and `*`.
/// Returns `nil` if an operand has a leading zero.
func expressionsReachingTargetEvaluate(_ text: String) -> Int? {
    var total = 0
    var term = 1
    var sign = 1
    var operandText = ""

    func closeOperand() -> Bool {
        if operandText.count > 1 && operandText.first == "0" {
            return false
        }
        term *= Int(operandText)!
        operandText = ""
        return true
    }

    for character in text {
        switch character {
        case "+", "-":
            guard closeOperand() else { return nil }
            total += sign * term
            term = 1
            sign = character == "+" ? 1 : -1
        case "*":
            guard closeOperand() else { return nil }
        default:
            operandText.append(character)
        }
    }
    guard closeOperand() else { return nil }
    return total + sign * term
}
