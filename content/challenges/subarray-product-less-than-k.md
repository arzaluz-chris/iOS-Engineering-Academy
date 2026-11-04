---
id: subarray-product-less-than-k
title: Subarray Product Less Than K
difficulty: medium
order: 17
patterns: [Sliding window, Counting windows]
prerequisites: [m07, m15, m16-l04]
summary: Count the stretches whose product stays under a limit. A sliding window that counts every valid stretch ending at each position, not just the longest.
solutionFile: SubarrayProductLessThanK.swift
testFile: SubarrayProductLessThanKTests.swift
starter: |
  func countLowProductStretches(_ values: [Int], below limit: Int) -> Int {
      // Your solution
      return 0
  }
time: O(n)
space: O(1)
edgeCases:
  - A limit of 0 or 1, which no product of positive integers can stay under
  - Empty input
  - All ones
  - A single element at or over the limit, which splits the array
askInterviewer:
  - Are all the values positive? (Zeros or negatives would break the window.)
  - Is the comparison strict, "less than", or "at most"?
  - Do single elements count as stretches?
  - Can the product overflow?
hints:
  - "With positive values, extending a stretch can only make its product bigger. What does that tell you about the stretches starting at a given position?"
  - "Use a window: for each right end, shrink from the left until the product is below the limit. How many valid stretches end at `right`?"
  - "Every stretch that ends at `right` and starts anywhere from `left` to `right` is valid: that's right − left + 1 of them."
followUps:
  - "Why does the window break if values can be 0 or negative?"
  - What if the question were "at most" instead of "less than"?
  - "How would you handle very large products without overflow? (Hint: logarithms, with care about rounding.)"
rubric:
  - I asked whether the values are positive and explained why it matters.
  - I counted right − left + 1 stretches per step instead of only tracking a maximum.
  - I shrank with a while loop guarded so the window can become empty.
  - I stated O(n) time with the amortized argument for the left pointer.
codeStatus: tested
---

A pricing team tests bundles: a bundle is a run of consecutive items from a catalog list, and its "multiplier" is the product of the items' factors. Given the factors (all positive integers) and a limit, count how many bundles have a multiplier **strictly less than** the limit. Single items count as bundles.

Write `countLowProductStretches(_ values: [Int], below limit: Int) -> Int`.

```swift
countLowProductStretches([4, 2, 6, 1], below: 30)  // 8
// [4] [2] [6] [1] [4, 2] [2, 6] [6, 1] [2, 6, 1]
countLowProductStretches([2, 3], below: 2)         // 0
countLowProductStretches([1, 1, 1], below: 1)      // 0: no product is less than 1
```

**Constraints:** `0 ≤ values.count ≤ 3·10^4`; `1 ≤ values[i] ≤ 1000`; `0 ≤ limit ≤ 10^6`.

<!-- reveal -->

## First approach

All values are positive, so a longer stretch never has a smaller product. That's the property a sliding window needs: once a stretch is too big, every stretch that contains it is too big too. For each right end, find the leftmost start that keeps the product under the limit. Then **every** start from there to `right` works, and they're all counted at once.

## Naive solution

For each start, extend to the right while the product stays under the limit:

```swift
func countLowProductStretches(_ values: [Int], below limit: Int) -> Int {
    var count = 0
    for start in values.indices {
        var product = 1
        for end in start..<values.count {
            product *= values[end]
            if product >= limit { break }
            count += 1
        }
    }
    return count
}
```

## Problems with the naive solution

The `break` helps, but with many small factors (lots of 1s) nothing stops the inner loop early, and it's **O(n²)**: about 4.5·10^8 steps for 3·10^4 ones. It also recomputes the product of overlapping stretches from scratch for each start.

## Optimized solution

Keep a window `left...right` and the product of its values. Each step, multiply in `values[right]`; while the product is at or over the limit, divide out `values[left]` and move `left` forward. Now the window is the longest valid stretch ending at `right`, and every shorter one ending there is valid too: add `right − left + 1` to the count.

## Line by line

- `product *= values[right]`: before this line the product is either 1 (empty window) or under `limit`, so it's at most 10^6 × 1000 = 10^9 here. No overflow.
- `while product >= limit && left <= right`: `while`, not `if`, because one large value can force several elements out. The `left <= right` guard lets the window become empty and stops there: when `limit` is 0 or 1, even the empty product 1 is too big.
- `product /= values[left]`: exact, because `values[left]` is one of the factors that were multiplied in.
- `count += right - left + 1`: the stretches `left...right`, `(left + 1)...right`, …, `right...right`. When the window is empty, `left` is `right + 1` and this adds 0.
- **O(n) time:** `left` only moves forward, so the inner loop runs at most n times in total. **O(1) space.**

## Common mistakes

- Adding 1 per step instead of `right − left + 1`, which counts only the longest stretch ending at each position.
- Shrinking with `if`. With `[2, 2, 2, 50]` and a limit of 10, adding 50 requires removing all four elements.
- Leaving out the `left <= right` guard. With a limit of 1, the product becomes 1 after the window empties, and the loop keeps dividing by elements past `right`, eventually reading past the end of the array.

## Variation

**Count stretches with sum at most k (non-negative values):** the same window with `+` and `−` instead of `*` and `/`. With negative values, both versions break, and you need prefix sums instead.
