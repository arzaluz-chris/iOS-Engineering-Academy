---
id: longest-step-subsequence
title: Longest Subsequence with a Fixed Step
difficulty: medium
order: 10
patterns: [Hash map, Dynamic programming]
prerequisites: [m07, m15, m16-l05]
summary: The longest chain of values, in their original order, where each one is exactly step more than the last. A dictionary remembers the best chain ending at each value.
solutionFile: LongestStepSubsequence.swift
testFile: LongestStepSubsequenceTests.swift
starter: |
  func longestStepSubsequence(_ values: [Int], step: Int) -> Int {
      // Your solution
      return 0
  }
time: O(n) on average
space: O(u) for u distinct values
edgeCases:
  - Empty list
  - A step of 0, where the answer is the count of the most repeated value
  - A negative step
  - A value that would continue a chain but appears before it, like [3, 2, 1] with step 1
  - Repeated values
askInterviewer:
  - Do the elements have to be next to each other, or only in order?
  - Can the step be 0 or negative?
  - Do I return the length or the subsequence itself?
  - How large can the values get? (Can value - step overflow?)
hints:
  - "This isn't \"longest run of consecutive numbers\": order matters, so a Set of values isn't enough. Which earlier element could come right before values[i] in a chain?"
  - "For each element, the best chain ending there is one longer than the best chain ending at value − step, among the elements seen so far."
  - "You don't need positions, only values: a dictionary from value to \"longest chain ending with this value so far\"."
followUps:
  - How would you return the subsequence itself, not just its length?
  - "Why does a Set-based approach (like the one for runs of consecutive days) fail here?"
  - What if any constant step is allowed and you have to find the best one? (Longest arithmetic subsequence, O(n²).)
rubric:
  - I clarified subsequence versus contiguous stretch.
  - I defined the state as "longest chain ending with this value" and wrote its update.
  - I used a dictionary keyed by value and got O(n) on average.
  - I handled a step of 0 without a special case.
codeStatus: tested
---

A strength-training app logs the weight of every set a user lifted, in order. The coach wants the longest **progression**: a selection of sets, in the order they happened (not necessarily back to back), where each weight is exactly `step` more than the previous one.

Write `longestStepSubsequence(_ values: [Int], step: Int) -> Int` that returns the length of the longest such selection. A single set counts as a progression of length 1.

```swift
longestStepSubsequence([5, 1, 7, 3, 9, 5, 7], step: 2)  // 4: 1, 3, 5, 7
longestStepSubsequence([4, 3, 2, 1], step: 1)           // 1: going down doesn't count
longestStepSubsequence([4, 3, 2, 1], step: -1)          // 4
```

**Constraints:** `0 ≤ values.count ≤ 10^5`; `-10^4 ≤ values[i], step ≤ 10^4`.

<!-- reveal -->

## First approach

Pick any element of the answer. The element right before it in the chain has the value `value − step` and comes **earlier** in the list. So for each element, the best chain ending there is one more than the best chain ending at an earlier `value − step`. If you remember, for every value, the longest chain that ends with it so far, each element is one lookup.

## Naive solution

For each element, scan every earlier element that could precede it:

```swift
func longestStepSubsequence(_ values: [Int], step: Int) -> Int {
    var lengths = Array(repeating: 1, count: values.count)
    for end in values.indices {
        for previous in 0..<end where values[previous] + step == values[end] {
            lengths[end] = max(lengths[end], lengths[previous] + 1)
        }
    }
    return lengths.max() ?? 0
}
```

## Problems with the naive solution

The inner loop looks at every earlier position: **O(n²)**, 5·10^9 checks for 10^5 elements. And it's searching for something specific (a value equal to `values[end] − step`), which is the signal for a hash lookup.

## Optimized solution

Keep a dictionary `longestEndingAt` from a value to the longest chain that ends with that value among the elements seen so far. For each element, its chain length is `longestEndingAt[value − step, default: 0] + 1`. Store it under `value`, and keep the maximum.

## Line by line

- `longestEndingAt[value - step, default: 0] + 1`: if no earlier element has the value `value − step`, the chain starts here with length 1.
- `longestEndingAt[value] = length`: overwriting is safe. A later copy of the same value is at the end of a chain at least as long as an earlier copy's, because it can extend everything the earlier one could, and the earlier one itself when `step` is 0.
- With `step` 0, `value − step` is `value`, so each copy of a value extends the previous copy's chain. The answer becomes the count of the most repeated value, with no special case.
- `longest = max(longest, length)`: the best chain can end anywhere, so the answer is tracked on every step. For an empty list, it stays 0.
- One dictionary lookup and one insert per element: **O(n) time on average**, **O(u) space** for u distinct values.

## Common mistakes

- Reaching for the Set trick from "longest run of consecutive days". It ignores order: for `[3, 2, 1]` with step 1, it would find 1, 2, 3 and answer 3, but in the list's order the answer is 1.
- Looking up `value + step` instead of `value − step`, which builds chains backward.
- Thinking you need the positions. The order is already handled by only looking at elements seen so far.

## Variation

**Longest arithmetic subsequence:** the step isn't given; find the longest subsequence with any constant step. The state becomes "longest chain ending at position i with step d", a dictionary per position, and it's O(n²). This problem is the special case where d is fixed, which is why it collapses to one dictionary.
