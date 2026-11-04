---
id: search-rotated-sorted-array
title: Search a Rotated Sorted Array
difficulty: medium
order: 48
patterns: [Binary search, Boundary search]
prerequisites: [m16-l02]
summary: Find a value in a sorted list that was rotated by an unknown amount, in O(log n). Find the rotation point, then search the right run.
solutionFile: SearchRotatedArray.swift
testFile: SearchRotatedArrayTests.swift
starter: |
  func searchRotatedArray(_ nums: [Int], _ target: Int) -> Int? {
      // Your solution
      return nil
  }
time: O(log n)
space: O(1)
edgeCases:
  - Empty list
  - Not rotated
  - Target that would fall between the two runs, or outside every value
  - Target equal to the first or last element
askInterviewer:
  - Are the values distinct?
  - Do I return nil or -1 when the target is missing?
  - Could the list not be rotated at all?
hints:
  - You already know how to find where the rotation happened in O(log n).
  - After that, the list is two sorted runs. Which one could contain the target? Compare it with the last element.
  - "One search can also do it all: at each step, at least one half of the range is sorted. Which one, and is the target in it?"
followUps:
  - Write the one-pass version that decides at each step which half is sorted.
  - What breaks when values can repeat?
  - How would you find the target's insertion point in the rotated list?
rubric:
  - I split the problem into finding the rotation point and searching one sorted run.
  - I picked the run by comparing the target with the last element.
  - I made sure the index the search returns is safe to read, and said why.
  - I stated O(log n) time and O(1) space.
codeStatus: tested
---

The playlist from the previous challenge is still rotated: sorted, distinct song IDs with some prefix moved to the end. Write `searchRotatedArray(_:_:)` that returns the index of `target`, or `nil` if it isn't in the list.

```swift
let ids = [40, 55, 70, 5, 12, 33]
searchRotatedArray(ids, 12)  // 4
searchRotatedArray(ids, 55)  // 1
searchRotatedArray(ids, 20)  // nil
```

**Constraints:** `0 ≤ nums.count ≤ 10^5`; values are distinct.

<!-- reveal -->

## First approach

If you knew where the rotation happened, the list would be two sorted runs, and you could binary search the right one. Finding the rotation point is the previous challenge: the first index whose value is `<= nums.last`. Which run to search follows from one comparison: every value in the right run is `<= nums.last`, every value in the left run is bigger.

## Naive solution

```swift
func searchRotatedArray(_ nums: [Int], _ target: Int) -> Int? {
    nums.firstIndex(of: target)
}
```

## Problems with the naive solution

Linear search is **O(n)**. It's correct for any list, sorted or not, and that's the problem: it uses none of the structure. With 10^5 elements it does up to 10^5 comparisons where binary search does about 34 (two searches of about 17).

## Optimized solution

Two boundary searches. The first finds `start`, the index of the minimum. Then, if `target <= nums.last`, it can only be in `start..<count`; otherwise only in `0..<start`. A lower bound on that range gives the position where the target would be, and one comparison says whether it's there.

## Line by line

- `guard let last = nums.last else { return nil }`: an empty list has nothing to find, and every later line needs `last`.
- The first loop is `minimumInRotatedArray` without the return: `nums[mid] > last` means `mid` is in the left run, so `low = mid + 1`; otherwise `high = mid`. `let start = low` keeps the result.
- `low = target <= last ? start : 0` and `high = target <= last ? nums.count : start`: pick the run. A target no bigger than `last` can only be in the right run; a bigger one only in the left run.
- The second loop is the lesson's lower bound on `low..<high`.
- `return nums[low] == target ? low : nil`: found only if the boundary holds the target. Reading `nums[low]` is safe without a range check, and it's worth saying why. In the right run, the last element is `>= target`, so the lower bound stops at `count - 1` at the latest. In the left run, `low` can end at `start`, one past the run, but `start` is a valid index, and it holds the minimum, which is `<= last < target`, so it can't be a false match.

## Common mistakes

- Searching the whole array, `0..<count`, in the second step. The list isn't sorted as a whole, so the lower bound is meaningless there.
- Choosing the run by comparing the target with `nums[start]` or `nums[0]` instead of `nums.last`. With `[50, 60, 10, 20, 30]` and target 55, `55 >= nums[start]` is true, but 55 can only be in the left run.
- In the one-pass version, using `<` where `<=` is needed when deciding whether the left half is sorted (`nums[low] <= nums[mid]`). With two elements, `low == mid`, and the strict comparison picks the wrong half.
- Forgetting the unrotated case. Here it falls out naturally: `start` is 0 and every target goes to the right run, which is the whole list.

## Variation

**One pass:** keep a closed range `low...high`. At each `mid`, one half is sorted: the left one if `nums[low] <= nums[mid]`, otherwise the right one. If the target lies inside the sorted half's range of values, search there; otherwise search the other half. Same O(log n), one loop, more conditions to get right. **With duplicates** (Search in Rotated Sorted Array II), `nums[low] == nums[mid]` gives no information; shrink by one and accept O(n) in the worst case.
