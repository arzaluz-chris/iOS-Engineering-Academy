---
id: contains-duplicate
title: Contains Duplicate
difficulty: easy
order: 2
patterns: [Hash set, Sorting]
prerequisites: [m07, m15]
summary: Does any value repeat? Your first run-in with the trade-off between time and memory.
solutionFile: ContainsDuplicate.swift
testFile: ContainsDuplicateTests.swift
starter: |
  func containsDuplicate(_ nums: [Int]) -> Bool {
      // Your solution
      return false
  }
time: O(n) on average
space: O(n)
edgeCases:
  - Empty list
  - A single element
  - Negatives and extreme values like Int.max
  - The duplicate is at the very end
askInterviewer:
  - How big can the list be?
  - Can I modify the input list, for example sort it in place?
  - Does extra memory matter?
hints:
  - Comparing every pair works, but how many pairs are there in a list of n elements?
  - Which data structure answers "have I seen this value already?" in constant time?
followUps:
  - If you can't use extra memory proportional to n, what do you do and what does it cost?
  - "What changes if the question is \"are there two equal values at most k positions apart?\" (Contains Duplicate II: a sliding window with a Set.)"
  - Why do we say "O(n) on average" for a Set, and not just "O(n)"?
rubric:
  - I proposed the brute-force solution first and explained its O(n²) cost.
  - I got to the Set solution with O(n) time and O(n) space.
  - I mentioned the sorting alternative, O(n log n), and when it makes sense.
codeStatus: tested
---

Given a list of integers `nums`, return `true` if any value appears at least twice, and `false` if every value is distinct.

```swift
containsDuplicate([1, 2, 3, 1])  // true
containsDuplicate([1, 2, 3, 4])  // false
```

**Constraints:** `0 ≤ nums.count ≤ 10^5`; values fit in `Int`.

<!-- reveal -->

## First approach

You have to compare each value with the others. The question is what that comparison costs, and whether you can remember what you've already seen so you don't repeat it.

## Naive solution

```swift
func containsDuplicate(_ nums: [Int]) -> Bool {
    for i in nums.indices {
        for j in (i + 1)..<nums.count where nums[i] == nums[j] {
            return true
        }
    }
    return false
}
```

## Problems with the naive solution

It compares every pair: n·(n−1)/2 comparisons, which is **O(n²)**. With 10^5 elements that's about 5·10^9 comparisons, far too many for an interactive response. It uses O(1) memory, and that's its only advantage.

## Optimized solution

Walk the list once and put each value in a `Set`. If an insert tells you the value was already there, you've found a duplicate. Each insert and lookup in a `Set` is O(1) on average, so the total is O(n) time in exchange for O(n) memory.

## Line by line

- `var seen = Set<Int>()`: the values seen so far.
- `seen.reserveCapacity(nums.count)`: keeps the `Set` from growing several times.
- `seen.insert(value)` returns a tuple; its `inserted` field is `false` if the value was already there. That's a lookup and an insert in a single operation.
- `return true` as soon as the first duplicate shows up: there's no need to finish the loop.
- The alternative, `containsDuplicateBySorting`, sorts a copy (O(n log n)) and compares neighbors: if there are duplicates, they end up next to each other.

## Common mistakes

- Building `Set(nums)` and comparing `count`. It works and it's O(n), but it always walks the whole list, even when the duplicate is in the first two positions. It's fine to mention as a concise alternative.
- Sorting the input list without asking whether you're allowed to modify it.
- Saying "O(1)" without qualifying it: hash tables have constant **average** cost, not guaranteed.

## Variation

**Contains Duplicate II:** return `true` if there are `i ≠ j` with `nums[i] == nums[j]` and `|i − j| ≤ k`. Keep a `Set` holding at most the last `k` values: a sliding window.
