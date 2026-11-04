---
id: expression-add-operators
title: Expression Add Operators
difficulty: hard
order: 58
patterns: [Backtracking, Expression evaluation]
prerequisites: [m18-l02, m18-l03]
summary: Insert +, - and * between digits to hit a target. Backtracking that evaluates as it goes, with a trick for multiplication's precedence.
solutionFile: ExpressionsReachingTarget.swift
testFile: ExpressionsReachingTargetTests.swift
starter: |
  func expressionsReachingTarget(_ digits: String, target: Int) -> [String] {
      // Your solution
      return []
  }
time: O(n · 4^n) for n digits
space: O(n) besides the output
edgeCases:
  - Operands with a leading zero, like "05", which aren't allowed
  - A single digit, and the whole string as one number
  - Negative targets
  - Results that depend on * binding tighter than + and -
askInterviewer:
  - Can I join digits into multi-digit numbers, or only put operators between single digits?
  - Is "05" a valid operand? Is "0"?
  - Is there a unary minus in front of the first number? (No.)
  - Does the order of the results matter?
hints:
  - "Between each pair of digits you have four choices: +, -, * or nothing. How many expressions does that make?"
  - Evaluate as you build, carrying the running value. Plus and minus are easy. What goes wrong with *?
  - Also carry the last term you added. To multiply it by the next operand, undo it first, then add it back multiplied.
followUps:
  - How would you add division, and what about division by zero and integer truncation?
  - How would you only count the expressions instead of listing them?
  - Where could the running value overflow, and how would you guard against it?
rubric:
  - I set up the backtracking over where each operand ends and which operator precedes it.
  - I carried the value and the last term, and applied * as value - last + last * operand.
  - I rejected operands with a leading zero.
  - I recorded an expression only when all digits were used and the value matched.
codeStatus: tested
---

A puzzle app shows a row of digits and a target number. Players insert `+`, `-` or `*` between some of the digits (or nothing, to join them into a longer number) so that the expression equals the target. Normal precedence applies: `*` before `+` and `-`. A number can't have a leading zero: `05` isn't allowed, `0` is. Write `expressionsReachingTarget(_:target:)` that returns every expression that works, in any order.

```swift
expressionsReachingTarget("124", target: 7)  // ["1+2+4"]
expressionsReachingTarget("232", target: 8)  // ["2*3+2", "2+3*2"]
expressionsReachingTarget("105", target: 5)  // ["1*0+5", "10-5"]
expressionsReachingTarget("37", target: 1)   // []
```

**Constraints:** `0 ≤ digits.count ≤ 10`; `digits` contains only `0` to `9`; `-2^31 ≤ target ≤ 2^31 − 1`.

<!-- reveal -->

## First approach

Each of the n − 1 gaps between digits gets one of four choices, so there are 4^(n−1) expressions. Generating them is backtracking; the interesting part is evaluating them without writing each one out and parsing it. Addition and subtraction can be applied to a running total right away. Multiplication can't, because in `2+3*2` the 3 was already added when the `*` shows up. The fix is to remember the last term: undo it, then add it back multiplied.

## Naive solution

Write out every expression, then evaluate each one with a small parser that respects precedence:

```swift
func expressionsReachingTarget(_ digits: String, target: Int) -> [String] {
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
        if let value = evaluate(text), value == target {   // nil if an operand has a leading zero
            results.append(text)
        }
        var gap = choice.count - 1          // next choice of operators, like counting in base 4
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
```

`evaluate` keeps a running total and the current product term; the solution file has it as `expressionsReachingTargetEvaluate`.

## Problems with the naive solution

The big-O is the same, O(n · 4ⁿ), but the constant is much worse. Every expression is built as a string and then parsed from scratch, so expressions that share a prefix, like `1+2+...` and `1+2*...`, evaluate it again each time. Invalid operands such as "05" are only rejected after the whole expression is built. Backtracking evaluates each prefix once and stops extending an operand the moment it would start with a zero.

## Optimized solution

`explore(from: start, value:, last:)` picks where the next operand ends. For each end, it reads the operand and, unless it's the first one, tries the three operators:

- `+`: `value + operand`, and the last term becomes `operand`.
- `-`: `value - operand`, and the last term becomes `-operand`.
- `*`: `value - last + last * operand`, and the last term becomes `last * operand`.

When `start` reaches the end of the digits, the expression is complete; keep it if `value == target`.

## Line by line

- `precondition(characters.allSatisfy { $0.isASCII && $0.isNumber }, ...)`: only `0` to `9`. `isNumber` alone would also accept characters like "½" or Arabic-Indic digits.
- `let lengthBefore = expression.count`: where the expression text should be cut back to after each try.
- `if end > start && characters[start] == "0" { break }`: an operand starting with 0 may only be "0" itself. Longer operands from this `start` would all have a leading zero, so the loop stops.
- `operand = operand * 10 + characters[end].wholeNumberValue!`: extends the operand by one digit without re-parsing. Ten digits fit easily in a 64-bit `Int`.
- `if start == 0 { expression = text; explore(..., value: operand, last: operand) }`: the first operand has no operator in front of it.
- The `+` and `-` branches append the operator and operand, recurse, and cut the text back with `removeLast(expression.count - lengthBefore)`.
- `explore(from: end + 1, value: value - last + last * operand, last: last * operand)`: the multiplication trick. For `2+3*2`, after `2+3` the value is 5 and the last term is 3. `*2` gives 5 − 3 + 3 · 2 = 8, and the last term becomes 6, ready for another `*`.
- With `-`, the last term is stored as `-operand`, so `2-3*2` gives (2 − 3) − (−3) + (−3) · 2 = −4, as it should.

## Common mistakes

- Applying `*` to the running value: `(2 + 3) * 2 = 10` instead of 8.
- Allowing "05" as an operand, or rejecting "0" as one.
- Forgetting to cut the expression text back after each branch, so later branches inherit the earlier operator.
- Building the operand by re-parsing the substring with `Int(...)` at every step. It's correct but slower, and it hides the leading-zero rule.

## Variation

**Target sum with signs only:** put `+` or `-` in front of every number in a list to reach a target, and count the ways. Without `*` and without joining, the order of operations doesn't matter, and the count can be found by dynamic programming over reachable sums instead of listing every expression.
