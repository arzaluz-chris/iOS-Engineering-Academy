---
id: product-of-array-except-self
title: Product of Array Except Self
difficulty: medium
order: 9
patterns: [Prefix products, Arrays]
prerequisites: [m07, m15, m16-l06]
summary: For every position, the product of everything else, without dividing. Prefix sums' idea, with multiplication, from both sides.
solutionFile: ProductOfArrayExceptSelf.swift
testFile: ProductOfArrayExceptSelfTests.swift
starter: |
  func productsExceptSelf(_ nums: [Int]) -> [Int] {
      // Your solution
      return []
  }
time: O(n)
space: O(1) extra besides the result
edgeCases:
  - One zero in the list
  - Two or more zeros
  - Negative values
  - Empty list and a single element
askInterviewer:
  - Am I allowed to use division?
  - Can the list contain zeros, and how many?
  - Is the result guaranteed to fit in Int?
  - Does the output array count toward the extra space?
hints:
  - "The product of everything except position i is (everything to its left) times (everything to its right)."
  - "How would you get \"the product of everything to the left\" for every position in one pass? It's the running total from prefix sums, with * instead of +."
  - "You can store the left products in the result array itself, then walk from the right with a single variable for the right products."
followUps:
  - "If division were allowed, what goes wrong with \"total product / nums[i]\"? How many zeros do you need to handle?"
  - How would you detect overflow instead of assuming the products fit?
  - "What's the sum version of this problem, and why is it easy?"
rubric:
  - I explained why division isn't safe even when it's allowed (zeros).
  - I split each answer into a left product and a right product.
  - I got to O(n) time with O(1) extra space besides the output.
  - I traced the two passes on an example with a zero.
codeStatus: tested
---

A dice game scores each player by multiplying the numbers everyone **else** rolled. Given a list of integers `nums`, return a list of the same length where position `i` holds the product of every element except `nums[i]`. **Don't use division.**

Write `productsExceptSelf(_ nums: [Int]) -> [Int]`.

```swift
productsExceptSelf([2, 3, 4, 5])   // [60, 40, 30, 24]
productsExceptSelf([-1, 2, 0, 4])  // [0, 0, -8, 0]
productsExceptSelf([7])            // [1]: the product of nothing is 1
```

**Constraints:** `0 ≤ nums.count ≤ 10^5`; `-30 ≤ nums[i] ≤ 30`. Every product of the other elements is guaranteed to fit in `Int`.

<!-- reveal -->

## First approach

The product of everything except position `i` splits in two: the product of `nums[0..<i]` and the product of `nums[(i + 1)...]`. Both are running products, one from the left and one from the right, the same idea as a prefix sum.

## Naive solution

For every position, multiply all the others:

```swift
func productsExceptSelf(_ nums: [Int]) -> [Int] {
    nums.indices.map { skipped in
        var product = 1
        for index in nums.indices where index != skipped {
            product *= nums[index]
        }
        return product
    }
}
```

## Problems with the naive solution

It's **O(n²)**: 10^5 elements means about 10^10 multiplications. The obvious shortcut, "multiply everything once and divide by `nums[i]`", is ruled out by the statement, and for good reason: with one zero, the total is 0, and at the zero's own position you'd compute 0 / 0, which traps in Swift (and the right answer there isn't 0 anyway). It's fixable by counting zeros, but it's a trap you'd be walking into.

## Optimized solution

Two passes. The first, left to right, writes into `result[i]` the product of everything **before** `i`. The second, right to left, multiplies `result[i]` by the product of everything **after** `i`, carried in one variable. Each pass is O(n), and the only extra memory besides the result is two integers.

Trace on `[2, 3, 4, 5]`:

| i | 0 | 1 | 2 | 3 |
| --- | --- | --- | --- | --- |
| after pass 1 (left products) | 1 | 2 | 6 | 24 |
| right product at i | 60 | 20 | 5 | 1 |
| result | 60 | 40 | 30 | 24 |

## Line by line

- `var result = Array(repeating: 1, count: nums.count)`: the output, also used as scratch space for the left products.
- `result[index] = leftProduct` **before** `leftProduct *= nums[index]`: position `i` must get the product of `nums[0..<i]`, without `nums[i]`. Swapping the two lines includes the element itself.
- `for index in nums.indices.reversed()`: the second pass goes right to left so `rightProduct` can grow one element at a time.
- `result[index] *= rightProduct` then `rightProduct *= nums[index]`: the same order for the same reason. Now `result[index]` is (left product) × (right product).
- For an empty list, both loops do nothing and the result is `[]`. For one element, both products are the empty product, 1.

## Common mistakes

- Updating the running product before writing it, which multiplies each element into its own answer.
- Using division and forgetting zeros, or dividing when the statement forbids it.
- Allocating separate `left` and `right` arrays and calling it O(1) space. That version is O(n) extra space; it's a fine stepping stone, just describe it accurately.

## Variation

**When division is allowed:** count the zeros first. With two or more, every answer is 0. With exactly one, every answer is 0 except at the zero's position, which gets the product of the other elements. With none, divide the total product by each element. It's also O(n) time and O(1) extra space, but it has three cases to get right, and the two-pass version has none.
