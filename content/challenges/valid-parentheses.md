---
id: valid-parentheses
title: Valid Parentheses
difficulty: easy
order: 5
patterns: [Stack]
prerequisites: [m07, m15]
summary: Check that parentheses, brackets and braces close in the right order. The problem that shows you what a stack is for.
solutionFile: ValidParentheses.swift
testFile: ValidParenthesesTests.swift
starter: |
  func isValidParentheses(_ s: String) -> Bool {
      // Your solution
      return false
  }
time: O(n)
space: O(n)
edgeCases:
  - Empty string
  - Only openers, like "(("
  - A closer with no opener, like ")"
  - Closers in the wrong order, like "([)]"
askInterviewer:
  - Which characters can the string contain? Do I ignore the others, or do they make it invalid?
  - Does the empty string count as valid?
hints:
  - Counting openers and closers isn't enough. Why does "([)]" have the same counts as "([])" and still not be valid?
  - Each closer has to match the most recent opener that's still open. Which data structure gives you "the most recent" in O(1)?
followUps:
  - How would you solve it with O(1) memory if there were only round parentheses?
  - "How do you find the length of the longest valid substring? (Longest Valid Parentheses.)"
  - Where does this pattern show up in a real app? (Validating templates, parsing expressions, undo.)
rubric:
  - I used a stack to match each closer with the most recent opener.
  - I rejected a closer when the stack is empty.
  - I checked that the stack is empty at the end.
  - I gave O(n) time and space complexity.
codeStatus: tested
---

Given a string made of `(`, `)`, `[`, `]`, `{` and `}`, return `true` if it's valid:

1. Every opener is closed by the same type.
2. Openers are closed in the correct order.
3. Every closer has an earlier opener of its type.

Any other character makes the string invalid. The empty string is valid.

```swift
isValidParentheses("()[]{}")  // true
isValidParentheses("([)]")    // false
isValidParentheses("{[]}")    // true
```

**Constraints:** `0 ≤ s.count ≤ 10^4`.

<!-- reveal -->

## First approach

The opener that has to close first is the last one that was opened. "Last in, first out" is exactly how a **stack** behaves.

## Naive solution

Keep deleting adjacent `()`, `[]` and `{}` pairs until there are none left:

```swift
func isValidParentheses(_ s: String) -> Bool {
    var current = s
    while true {
        let reduced = current
            .replacingOccurrences(of: "()", with: "")
            .replacingOccurrences(of: "[]", with: "")
            .replacingOccurrences(of: "{}", with: "")
        if reduced == current { return current.isEmpty }
        current = reduced
    }
}
```

`replacingOccurrences` comes from Foundation; this snippet needs `import Foundation`.

## Problems with the naive solution

Each pass walks the string and may only remove one level of nesting. With `"((((…))))"` nested n/2 deep you need n/2 passes: **O(n²)**. It also creates a new string on every replacement.

## Optimized solution

Walk the string once. Push every opener. On a closer, pop the last element off the stack and check that it's the matching opener. At the end, the stack must be empty.

## Line by line

- `openerFor`: a dictionary from each closer to its opener. It saves you a chain of `if`s.
- `openers`: the set of openers, so you can ask about membership in O(1).
- `stack.append(character)`: the opener is now pending.
- `guard stack.popLast() == expectedOpener`: `popLast()` returns an optional, `nil` if the stack is empty. Comparing that optional with the expected opener covers two failures in one line: a closer with no opener, and a closer of the wrong type.
- `else { return false }`: any other character makes the string invalid, as the problem says.
- `return stack.isEmpty`: if there are openers left unclosed, as in `"(("`, the string isn't valid.

## Common mistakes

- Counting openers and closers of each type: `"([)]"` has the right counts and is still invalid.
- Calling `removeLast()` without checking whether the stack is empty: it crashes the program on `")"`.
- Forgetting to check the stack at the end.

## Variation

If there are only round parentheses, a counter is enough: add 1 for each opener, subtract 1 for each closer, fail if it drops below 0, and require 0 at the end. O(1) memory.
