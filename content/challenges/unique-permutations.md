---
id: unique-permutations
title: Unique Permutations
difficulty: medium
order: 53
patterns: [Backtracking, Permutations, Skipping duplicates]
prerequisites: [m18-l02]
summary: Generate every distinct ordering of a list that has repeated values. One extra rule in the permutations generator keeps equal values in a fixed order.
solutionFile: UniquePermutations.swift
testFile: UniquePermutationsTests.swift
starter: |
  func uniquePermutations(_ nums: [Int]) -> [[Int]] {
      // Your solution
      return []
  }
time: O(n · n!) in the worst case
space: O(n) besides the output
edgeCases:
  - Empty list, which has one ordering
  - All values equal, which has exactly one
  - All values distinct, which has n!
  - Several groups of repeats, like [1, 1, 2, 2, 3, 3]
askInterviewer:
  - Does the order of the results matter?
  - Can the input be modified, or sorted?
  - How long can the list be? The output alone is n! in the worst case.
hints:
  - Run the lesson's permutations generator on [2, 1, 2]. Which results appear twice, and why?
  - Two copies of the same value are interchangeable. What if you only allowed them to be placed in their original left-to-right order?
  - After sorting, place a copy only when the copy just before it is already in use.
followUps:
  - How many distinct orderings are there? (n! divided by the factorial of each value's count.)
  - Write it with a dictionary of remaining counts instead of a used array.
  - How do you get the next permutation in lexicographic order, in place, without generating the rest?
rubric:
  - "I identified where the duplicates come from: equal values at different positions."
  - I sorted, and skipped a copy when the previous copy is not in use.
  - I explained why each distinct ordering is still produced exactly once.
  - I didn't use a Set of results to deduplicate.
codeStatus: tested
---

A playlist editor has a "shuffle every way" preview that lists each possible order of the songs. Some songs appear more than once, and two orders that look the same shouldn't be listed twice. Write `uniquePermutations(_:)` that returns every distinct ordering of `nums`, in any order.

```swift
uniquePermutations([2, 1, 2])  // [[1, 2, 2], [2, 1, 2], [2, 2, 1]]
uniquePermutations([3, 3])     // [[3, 3]]
uniquePermutations([])         // [[]]
```

**Constraints:** `0 ≤ nums.count ≤ 8`; `-10 ≤ nums[i] ≤ 10`.

<!-- reveal -->

## First approach

The lesson's permutations generator treats the two 2s in `[2, 1, 2]` as different items, so every ordering appears twice: once with the first 2 in front, once with the second. Fix one order among equal values, say "the first copy is always placed before the second", and each distinct arrangement can be built in exactly one way.

## Naive solution

Generate all n! orderings by position and keep the first copy of each:

```swift
func uniquePermutations(_ nums: [Int]) -> [[Int]] {
    var seen = Set<[Int]>()
    var results: [[Int]] = []
    var current: [Int] = []
    var used = Array(repeating: false, count: nums.count)

    func explore() {
        if current.count == nums.count {
            if seen.insert(current).inserted {
                results.append(current)
            }
            return
        }
        for i in nums.indices where !used[i] {
            used[i] = true
            current.append(nums[i])
            explore()
            current.removeLast()
            used[i] = false
        }
    }

    explore()
    return results
}
```

## Problems with the naive solution

It always does n! leaves of work. Eight copies of the same value have one distinct ordering, and this builds 40,320 identical arrays to find it. The `Set` also stores every result a second time. Like the subsets version, the work follows the positions, not the answer.

## Optimized solution

Sort, so copies are adjacent. In the loop that picks the next element, skip `i` when `sorted[i] == sorted[i - 1]` and `sorted[i - 1]` is **not** in use. That means a copy can only be placed after the copy to its left has been placed, so copies always go in left-to-right order, and the duplicate branches are never entered.

## Line by line

- `let sorted = nums.sorted()`: puts equal values next to each other.
- `var used = Array(repeating: false, count: sorted.count)`: which positions are already in `current`, as in the lesson.
- `if current.count == sorted.count`: a full ordering; record it and return.
- `for i in sorted.indices where !used[i]`: every position not placed yet.
- `if i > 0 && sorted[i] == sorted[i - 1] && !used[i - 1] { continue }`: the rule. If the previous copy is free, placing this copy now would put it before the previous one; the branch where the previous copy goes here instead builds the same arrangements.
- `used[i] = true`, `current.append(...)`, `explore()`, then undo both: choose, explore, unchoose.

## Common mistakes

- Using the subsets rule (`i > start`). There's no `start` in permutations; every unused position is a candidate at every level, so the condition has to be about `used`.
- Writing `used[i - 1]` instead of `!used[i - 1]`. Surprisingly, that also produces each ordering once (it forces copies in right-to-left order), but it prunes much later and explores far more dead branches. If you write it, be ready to explain why it still works.
- Forgetting to sort.

## Variation

**Counts instead of positions:** build `[value: count]`, and at each level loop over the distinct values with a count above zero: decrement, recurse, increment. Each level only offers each value once, so duplicates never arise, and there's no sort or skip rule.
