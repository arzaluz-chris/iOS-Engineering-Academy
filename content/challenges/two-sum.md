---
id: two-sum
title: Two Sum
difficulty: easy
order: 3
patterns: [Hash map, Complement lookup]
prerequisites: [m07, m08, m15]
summary: Find two positions whose values add up to a target. The textbook case of trading memory for time with a dictionary.
solutionFile: TwoSum.swift
testFile: TwoSumTests.swift
starter: |
  func twoSum(_ nums: [Int], _ target: Int) -> [Int]? {
      // Your solution
      return nil
  }
time: O(n) on average
space: O(n)
edgeCases:
  - Two equal values that add up to the target, like [3, 3] with 6
  - A value that's half the target but appears only once
  - Negatives and zero
  - No solution
askInterviewer:
  - Is there always exactly one solution, or do I need to handle none or several?
  - Do I return indices or values?
  - Is the list sorted?
  - Can values repeat?
hints:
  - For each number `x`, which number do you need to find? Write it in terms of `target` and `x`.
  - If you stored the numbers you've already walked past along with their index, how much would it cost to ask whether you've seen the one you need?
  - Look up the complement before you store the current number. Why does that order matter?
followUps:
  - If the list were sorted, how would you solve it with O(1) extra memory? (Two pointers.)
  - What if you have to return every distinct pair?
  - What's the risk of computing target - x when values are close to Int.max?
rubric:
  - I explained the O(n²) solution and why it doesn't scale.
  - I used a dictionary from value to index to find the complement in O(1) on average.
  - I looked up the complement before inserting the current value, so the same index is never used twice.
  - I handled the no-solution case.
codeStatus: tested
---

Given a list of integers `nums` and an integer `target`, return the indices `[i, j]` of two **different** elements (`i ≠ j`) that add up to `target`, with `i < j`. If there aren't any, return `nil`.

```swift
twoSum([2, 7, 11, 15], 9)  // [0, 1]  because 2 + 7 = 9
twoSum([3, 2, 4], 6)       // [1, 2]  because 2 + 4 = 6
twoSum([3, 3], 6)          // [0, 1]
twoSum([1, 2, 3], 100)     // nil
```

**Constraints:** `0 ≤ nums.count ≤ 10^4`; `-10^9 ≤ nums[i], target ≤ 10^9`. If there are several solutions, return the one whose second index is smallest.

<!-- reveal -->

## First approach

For each number `x`, the number that completes it is `target - x`. So the problem comes down to answering one question quickly: "have I already seen `target - x`, and at what position?"

## Naive solution

Try every pair `(i, j)` with `i < j`:

```swift
func twoSum(_ nums: [Int], _ target: Int) -> [Int]? {
    for i in nums.indices {
        for j in (i + 1)..<nums.count where nums[i] + nums[j] == target {
            return [i, j]
        }
    }
    return nil
}
```

## Problems with the naive solution

It's **O(n²)** time. With 10^4 elements that's about 5·10^7 additions. It works, but in an interview the expected next step is to beat it. Its one advantage is O(1) memory; say so, because that's a real trade-off.

## Optimized solution

Walk the list once. For each value, look up its complement in a `[value: index]` dictionary of what you've already seen. If it's there, you're done. If not, store the current value and keep going.

## Line by line

- `var indexByValue: [Int: Int] = [:]`: for each value seen so far, its index.
- `for (index, value) in nums.enumerated()`: walks the list with position and value together.
- `if let complementIndex = indexByValue[target - value]`: reading a dictionary returns an optional, because the key might not exist. `if let` unwraps it only when it does.
- `return [complementIndex, index]`: the complement was seen earlier, so its index is smaller.
- `indexByValue[value] = index`: stored **after** the lookup. If you stored it first, with `[3, 5]` and a target of 6, the 3 would find itself as its own complement.
- If values repeat, the later assignment overwrites the earlier index. That's fine: any valid pair gets caught when the loop reaches its second element.

## Common mistakes

- Inserting before looking up, and pairing an element with itself.
- Sorting the list to use two pointers and losing the original indices.
- Calling `firstIndex(of:)` inside the loop. It looks O(n), but it's O(n²), because `firstIndex` walks the list.

## Variation

**Two Sum II** (sorted list): one index at the start and one at the end. If the sum is less than the target, move the left one forward; if it's greater, move the right one back. O(n) time and O(1) memory.
