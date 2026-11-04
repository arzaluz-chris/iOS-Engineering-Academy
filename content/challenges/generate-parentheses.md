---
id: generate-parentheses
title: Generate Parentheses
difficulty: medium
order: 27
patterns: [Backtracking, Pruning, Stack invariant]
prerequisites: [m18-l02, m18-l03, m17-l01]
summary: List every balanced string of n pairs of parentheses. Pruning invalid prefixes as you build them means you never generate a string you'll throw away.
solutionFile: GenerateParentheses.swift
testFile: GenerateParenthesesTests.swift
starter: |
  func generateParentheses(_ pairs: Int) -> [String] {
      // Your solution
      return []
  }
time: O(n · C(n)), which is O(4^n / √n); C(n) is the n-th Catalan number
space: O(n) besides the output
edgeCases:
  - Zero pairs, which has exactly one answer, the empty string
  - One pair
  - The largest allowed n, where the brute force starts to hurt
askInterviewer:
  - Does the order of the results matter?
  - What should n = 0 return, an empty list or a list with the empty string?
  - Only round parentheses, or several bracket types?
hints:
  - "A string of n pairs is balanced when no prefix has more \")\" than \"(\", and the totals are equal. Can you check the first rule while you build the string, one character at a time?"
  - At any point, when is adding "(" allowed? When is adding ")" allowed?
  - "Track two counts, opened and closed. \"(\" needs opened < n; \")\" needs closed < opened. When closed reaches n, the string is complete."
followUps:
  - How many results are there for n pairs, and why is it the Catalan number?
  - How would you generate the k-th string in lexicographic order without generating the ones before it?
  - What changes if you also allow square brackets, and they must nest properly with the round ones?
rubric:
  - I stated the two rules (never more closers than openers in a prefix; equal totals at the end).
  - I pruned while building, so every partial string can still be completed.
  - I mutated one buffer and undid each choice, or explained the cost of copying instead.
  - I gave the complexity in terms of the number of results, not as 2^(2n).
codeStatus: tested
---

A UI test generator needs every way to nest n push and pop transitions of a navigation stack, written as balanced parentheses: `(` is a push and `)` is the matching pop. Write `generateParentheses(_:)` that returns every balanced string with exactly `pairs` opening and `pairs` closing parentheses, in lexicographic order (`(` comes before `)`).

```swift
generateParentheses(1)   // ["()"]
generateParentheses(2)   // ["(())", "()()"]
generateParentheses(3)   // ["((()))", "(()())", "(())()", "()(())", "()()()"]
generateParentheses(0)   // [""]
```

**Constraints:** `0 ≤ pairs ≤ 8`.

<!-- reveal -->

## First approach

Every answer has length 2n, and each position is `(` or `)`. That's a tree of choices, which is backtracking (lesson m18-l02). Most branches lead nowhere: a string that starts with `)` can never be fixed. The [Valid Parentheses](#/challenge/valid-parentheses) idea tells you what "valid" means, and with only one bracket type you don't need a stack to check it, just a count. So the plan is to check the rules **while** you choose (lesson m18-l03), not at the end.

## Naive solution

Build all 2^(2n) strings of length 2n and keep the balanced ones:

```swift
func generateParentheses(_ pairs: Int) -> [String] {
    let length = 2 * pairs
    var results: [String] = []
    for mask in 0..<(1 << length) {
        var characters: [Character] = []
        var balance = 0
        var valid = true
        for position in 0..<length {
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
```

Reading each mask from its highest bit, with `(` as 0, produces the strings in lexicographic order.

## Problems with the naive solution

It looks at **4^n** masks to keep C(n) of them. For n = 8 that's 65,536 masks for 1,430 answers, about 2% useful work, and the ratio gets worse as n grows, because C(n) is roughly 4^n / (n^1.5 · √π). The fix isn't a faster check; it's never building the strings that fail.

## Optimized solution

Recursive backtracking with two counters, `opened` and `closed`. Add `(` if fewer than n have been used. Add `)` only if `closed < opened`, which is exactly "this prefix never has more closers than openers". When `closed == pairs`, both totals are n and the string is complete. Every partial string the recursion builds can still be finished, so there are no dead ends: the work is proportional to the output. Trying `(` before `)` produces the results in lexicographic order.

## Line by line

- `guard pairs >= 0 else { return [] }`: a negative count has no answers.
- `var current: [Character] = []`: one shared buffer. Each choice appends and then undoes itself with `removeLast()`, so no string is copied until a result is complete.
- `func extend(opened: Int, closed: Int)`: a nested function, so it can read `pairs` and mutate `results` and `current` without passing them around.
- `if closed == pairs`: since `closed` never passes `opened` and `opened` never passes `pairs`, this means both are n. `results.append(String(current))` copies the finished string.
- `if opened < pairs`: room for another opener. Append, recurse with `opened + 1`, remove.
- `if closed < opened`: a closer has an opener to match. Append, recurse with `closed + 1`, remove.
- `extend(opened: 0, closed: 0)`: start from the empty prefix. For `pairs == 0`, the first call sees `closed == pairs` and records `""`.

Each result is 2n characters, and every node of the recursion tree lies on a path to some result, so there are at most 2n · C(n) nodes: **O(n · C(n)) = O(4^n / √n) time**. The recursion is at most 2n deep and the buffer holds 2n characters: **O(n) space** besides the output.

## Common mistakes

- Allowing `)` whenever `closed < pairs`. That produces strings like `)(` and needs a filter at the end.
- Building a new `String` at every step (`current + "("`) instead of mutating one buffer. It's correct but copies O(n) characters per node.
- Forgetting the `removeLast()` after a recursive call, so later branches inherit characters from earlier ones.
- Returning `[]` for n = 0. The empty string is one balanced string with zero pairs.
- Stating the time as O(2^(2n)), the size of the unpruned tree.

## Variation

**Remove Invalid Parentheses**: given a string with letters and unbalanced parentheses, remove the fewest parentheses to make it valid and return every distinct result. Count how many openers and closers must go first, then backtrack over removals with the same "never more closers than openers" check, skipping duplicate removals in a row.
