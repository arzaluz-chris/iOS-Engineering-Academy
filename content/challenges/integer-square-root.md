---
id: integer-square-root
title: Integer Square Root
difficulty: easy
order: 44
patterns: [Binary search on the answer]
prerequisites: [m15-l03, m16-l02]
summary: Find the whole-number square root without calling sqrt. A first binary search over answers instead of over an array, with an overflow trap built in.
solutionFile: IntegerSquareRoot.swift
testFile: IntegerSquareRootTests.swift
starter: |
  func integerSquareRoot(_ n: Int) -> Int {
      // Your solution
      return 0
  }
time: O(log n)
space: O(1)
edgeCases:
  - 0 and 1, which are their own roots
  - Perfect squares, and the value right below one (24 and 25)
  - Int.max, where mid * mid overflows
askInterviewer:
  - Do I round down, or to the nearest whole number?
  - Can n be negative?
  - Can I use sqrt from Foundation? (Usually no; that's the point.)
  - How large can n get? Does it fit in 32 bits or the full Int range?
hints:
  - The answer is between 0 and n. If you guess r, can you tell whether the real root is smaller or larger?
  - '"r * r > n" is false for small r and true from some point on. That boundary is one more than the answer.'
  - For n near Int.max, r * r crashes. Compare r with n / r instead.
followUps:
  - How would you return the root with 3 decimal places? (Search over fixed-point values, or refine with Newton's method.)
  - "Newton's method: r = (r + n / r) / 2 converges much faster. Why does it still need care with integers?"
  - Why is the floating-point sqrt(Double(n)) risky for n close to Int.max?
rubric:
  - I recognized a monotonic yes/no condition over candidate answers and searched over it.
  - I picked a range that is guaranteed to contain the answer and handled 0 and 1.
  - I avoided overflow by comparing with a division instead of a multiplication.
  - I explained why the search ends and why it runs in O(log n).
codeStatus: tested
---

A fitness app shows the side length of the largest square floor plan you can tile with `n` one-meter tiles. Write `integerSquareRoot(_:)` that returns the largest whole number `r` with `r * r <= n`. Don't use `sqrt` or `pow`.

```swift
integerSquareRoot(16)  // 4
integerSquareRoot(20)  // 4, because 4 * 4 = 16 <= 20 and 5 * 5 = 25 > 20
integerSquareRoot(1)   // 1
integerSquareRoot(0)   // 0
```

**Constraints:** `0 ≤ n ≤ Int.max`.

<!-- reveal -->

## First approach

There's no array here, only a range of possible answers, 0 through n. For each candidate `r`, the question "is `r * r` bigger than `n`?" is answered `false` for small `r` and `true` from some point on, never switching back. That's the shape Module 16 calls a monotonic condition, so binary search finds the switch point. The answer is the last `r` before it.

## Naive solution

Count up while the next number still fits:

```swift
func integerSquareRoot(_ n: Int) -> Int {
    var root = 0
    while (root + 1) * (root + 1) <= n {
        root += 1
    }
    return root
}
```

## Problems with the naive solution

It does √n steps. For n = 10^18 that's 10^9 iterations, several seconds at best. It also crashes near `Int.max`: when `root + 1` reaches 3,037,000,500, the product no longer fits in 64 bits, and Swift traps on overflow instead of wrapping. The tested version in the solution file avoids the crash by writing the check as `root + 1 <= n / (root + 1)`, but it's still O(√n).

## Optimized solution

Binary search for the first `r` where `r > n / r`, which for positive `r` means the same as `r * r > n` without multiplying. For n ≥ 2 that `r` is somewhere in `1...(n / 2 + 1)`, so that's the search range, and the answer is one less than what the search finds.

## Line by line

- `precondition(n >= 0, ...)`: negative input has no real square root; the problem rules it out, and the precondition says so in the code.
- `if n < 2 { return n }`: 0 and 1 are their own roots. Handling them up front also keeps `mid` from ever being 0, so `n / mid` is safe.
- `var low = 1` and `var high = n / 2 + 1`: the first "too big" root is in this range. For n ≥ 2, `(n / 2 + 1)²` is always greater than n, so `high` itself qualifies, and the half-open loop can treat it as the answer it falls back to.
- `while low < high`: the same half-open loop as the lesson's lower bound. It ends when the range is empty.
- `let mid = low + (high - low) / 2`: the midpoint without adding `low + high`, which could overflow for huge n.
- `if mid > n / mid`: with integer division, `mid > n / mid` is true exactly when `mid * mid > n`. If it's true, `mid` might be the first too-big root, so `high = mid` keeps it. Otherwise `mid` fits, the answer is at least `mid`, and `low = mid + 1` rules it out as the boundary.
- `return low - 1`: `low` is the first root that's too big; the one before it is the largest that fits.

## Common mistakes

- Computing `mid * mid`. It works in tests with small numbers and crashes on large ones.
- Using `high = n` and `low <= high` with `high = mid - 1`, then returning the wrong side of the boundary. Pick one convention and check the return value on 8 (answer 2) and 9 (answer 3).
- Calling `Int(Double(n).squareRoot())`. A `Double` has 53 bits of precision, so for n near `Int.max` it rounds `n` before taking the root and can be off by one.

## Variation

**Valid perfect square:** return whether `n` is a perfect square. It's the same search followed by `root * root == n`, or a search for an exact match. **Nth root:** the largest `r` with `r^k <= n`; the check becomes a loop that multiplies `r` k times and stops as soon as the product passes n.
