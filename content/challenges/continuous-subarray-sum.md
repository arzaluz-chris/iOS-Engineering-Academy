---
id: continuous-subarray-sum
title: Continuous Subarray Sum
difficulty: medium
order: 21
patterns: [Prefix sums, Hash map, Modular arithmetic]
prerequisites: [m07, m15, m16-l05, m16-l06]
summary: Is there a stretch of at least two elements whose sum is a multiple of k? Prefix sums, remainders, and the first place each remainder showed up.
solutionFile: ContinuousSubarraySum.swift
testFile: ContinuousSubarraySumTests.swift
starter: |
  func hasStretchSummingToMultiple(_ values: [Int], of k: Int) -> Bool {
      // Your solution
      return false
  }
time: O(n) on average
space: O(min(n, k))
edgeCases:
  - A single element that's a multiple of k, which isn't enough on its own
  - Two zeros next to each other (0 is a multiple of every k)
  - k = 1, where any two elements work
  - Negative values, which make Swift's % return negative remainders
  - Empty input
askInterviewer:
  - What's the minimum length of the stretch?
  - Does 0 count as a multiple of k?
  - Can values be negative? Can k be 0 or negative?
  - Do I need the stretch itself, or just whether it exists?
hints:
  - "With prefix sums, the stretch values[l..<r] sums to prefix[r] − prefix[l]. When is that difference a multiple of k?"
  - "It's a multiple of k exactly when prefix[r] and prefix[l] have the same remainder modulo k. So you're looking for two equal remainders at least two positions apart."
  - "To make \"at least two apart\" easy to check, store only the first position where each remainder appeared. And normalize negative remainders."
followUps:
  - How would you count all such stretches instead of answering yes or no?
  - "What if the minimum length were L instead of 2?"
  - Why does storing the first position, and never overwriting it, give the longest stretch for each remainder?
rubric:
  - I translated "sum is a multiple of k" into "two prefix sums with the same remainder".
  - I stored the first prefix length for each remainder and checked the distance against 2.
  - "I normalized remainders for negative values with ((x % k) + k) % k."
  - I seeded the dictionary with remainder 0 at length 0 so stretches starting at the first element count.
codeStatus: tested
---

A warehouse ships items in crates that hold exactly `k` units. Given the net change in stock for each day (negative when more left than arrived), decide whether some stretch of **at least two consecutive days** has a total that's a multiple of `k`, so it could be packed into whole crates with nothing left over. Zero counts as a multiple.

Write `hasStretchSummingToMultiple(_ values: [Int], of k: Int) -> Bool`.

```swift
hasStretchSummingToMultiple([5, 7, 2, 4], of: 6)  // true: 5 + 7 = 12
hasStretchSummingToMultiple([5, 7, 2, 3], of: 8)  // false
hasStretchSummingToMultiple([6], of: 6)           // false: one day isn't a stretch
hasStretchSummingToMultiple([-4, 1], of: 3)       // true: −3
```

**Constraints:** `0 ≤ values.count ≤ 10^5`; `-10^4 ≤ values[i] ≤ 10^4`; `1 ≤ k ≤ 10^9`.

<!-- reveal -->

## First approach

The prefix sums lesson turned "a stretch sums to t" into "two prefix sums differ by t". Here the difference has to be a multiple of `k`, which happens exactly when the two prefix sums leave the **same remainder** when divided by `k`. So walk the prefix sums, and look for a remainder you've seen before at least two positions back.

## Naive solution

Try every stretch of length two or more, with a running sum per start:

```swift
func hasStretchSummingToMultiple(_ values: [Int], of k: Int) -> Bool {
    for start in values.indices {
        var sum = values[start]
        for end in (start + 1)..<values.count {
            sum += values[end]
            if sum % k == 0 {
                return true
            }
        }
    }
    return false
}
```

`sum % k == 0` is safe with negative sums: in Swift `-12 % 6` is `0`.

## Problems with the naive solution

It's **O(n²)**: about 5·10^9 additions for 10^5 days in the worst case (when the answer is `false`, every stretch gets checked).

## Optimized solution

Let `prefix` be the sum of the first `length` values, and `remainder` its remainder modulo `k`, normalized into `0..<k`. A dictionary maps each remainder to the **first** prefix length where it appeared, starting with remainder 0 at length 0 (the empty prefix). For each new prefix, if its remainder was seen at a length at least 2 smaller, the stretch between them has at least two elements and a sum that's a multiple of `k`.

## Line by line

- `var firstPrefixLength: [Int: Int] = [0: 0]`: the empty prefix has sum 0 and length 0. It's what lets a stretch that starts at day 0 be found, like `[6, 0]`.
- `prefix += value` and `let length = index + 1`: `prefix` is the sum of the first `length` values.
- `((prefix % k) + k) % k`: Swift's `%` keeps the sign of the left operand, so `-4 % 3` is `-1`, not `2`. Adding `k` and taking `%` again maps both to `2`, so prefixes that differ by a multiple of `k` always get the same key.
- `if let earlier = firstPrefixLength[remainder]`: the same remainder appeared at prefix length `earlier`, so `values[earlier..<length]` sums to a multiple of `k`.
- `if length - earlier >= 2`: that stretch has `length − earlier` elements. If it's only one, don't give up on the remainder: a later prefix may be farther from `earlier`.
- `else { firstPrefixLength[remainder] = length }`: only the first occurrence is stored, which gives each later prefix the longest possible stretch to check. Overwriting would lose cases like `[6, 0]` with `k = 6`, where the remainder 0 appears at lengths 0, 1 and 2.
- **O(n) time on average, O(min(n, k)) space**: there are at most `k` remainders and at most n + 1 prefixes.

## Common mistakes

- Using `prefix % k` directly as the key. With negative values, remainders `-1` and `2` (for `k = 3`) describe the same class but are different keys.
- Forgetting the `[0: 0]` seed, which misses stretches that start at the first day.
- Overwriting the stored length on every occurrence, so the two-element minimum fails when it shouldn't.
- Accepting a single element: `[6]` with `k = 6` has a one-day stretch that's a multiple, and the answer is still `false`.

## Variation

**Count the stretches whose sum is divisible by k, of any length:** store how many times each remainder has appeared instead of where it first appeared, and add that count at every step, exactly like counting stretches with a given sum.
