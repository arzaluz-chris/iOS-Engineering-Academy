---
id: next-greater-element-circular
title: Next Greater Element in a Circular Array
difficulty: medium
order: 28
patterns: [Monotonic stack, Circular array]
prerequisites: [m17-l05]
summary: For each value in a list that wraps around, find the first bigger value ahead of it. A monotonic stack and a second lap over the array.
solutionFile: NextGreaterCircular.swift
testFile: NextGreaterCircularTests.swift
starter: |
  func nextGreaterCircular(_ values: [Int]) -> [Int] {
      // Your solution
      return []
  }
time: O(n)
space: O(n)
edgeCases:
  - Empty array and a single element (no other element to beat it)
  - All values equal, where nothing is strictly greater
  - The maximum, which always gets -1, possibly more than once
  - An answer that's only found after wrapping past the end
  - Negative values, so -1 can't be read as "not found" from the value alone
askInterviewer:
  - Does "greater" mean strictly greater?
  - What should I return when there's no greater element? Is -1 safe if values can be negative?
  - Do you want the value or the distance to it?
hints:
  - Solve it first for a normal, non-circular array with a monotonic stack (lesson m17-l05). Which elements are left without an answer at the end?
  - The elements still waiting at the end need to see the elements before them. What if you walked the array a second time?
  - On the second lap, should you push indexes again?
followUps:
  - How would you return distances (how many steps ahead) instead of values?
  - "What changes if -1 can be a real value in the input? (Return [Int?] instead.)"
  - How would you find the next greater element for a stream of values that arrives one at a time and never wraps?
rubric:
  - I recognized the next-greater pattern and used a decreasing stack of indexes.
  - I handled the wraparound with a second pass using modulo, without copying the array.
  - I pushed only during the first pass, and explained why each index is pushed and popped at most once.
  - I used a strict comparison so equal values don't count as greater.
codeStatus: tested
---

A smart thermostat repeats the same list of target temperatures every week. For each slot in the list, the app wants to show the next target that's **strictly** warmer, looking forward and wrapping around into the next week. Write `nextGreaterCircular(_:)` that returns, for each position, the first strictly greater value found by walking forward (after the last element comes the first), or `-1` if no element is greater.

```swift
nextGreaterCircular([3, 8, 4, 1, 6])   // [8, -1, 6, 6, 8]
nextGreaterCircular([5, 4, 3, 2])      // [-1, 5, 5, 5]
nextGreaterCircular([2, 2, 2])         // [-1, -1, -1]
```

In the first example, the 6 at the end wraps around: 3 isn't greater, 8 is.

**Constraints:** `0 ≤ values.count ≤ 10^4`; `-10^9 ≤ values[i] ≤ 10^9`.

<!-- reveal -->

## First approach

Without the wraparound, this is the next greater element from lesson m17-l05: a stack of indexes waiting for their answer, with decreasing values from bottom to top. The wraparound only matters for the indexes still waiting after one pass, and what they need to see is the start of the array. Walking the array a second time shows it to them.

## Naive solution

From each position, look ahead up to n − 1 steps, wrapping with `%`:

```swift
func nextGreaterCircular(_ values: [Int]) -> [Int] {
    let count = values.count
    var answers = Array(repeating: -1, count: count)
    for index in 0..<count {
        for offset in 1..<max(count, 1) {
            let candidate = values[(index + offset) % count]
            if candidate > values[index] {
                answers[index] = candidate
                break
            }
        }
    }
    return answers
}
```

`max(count, 1)` keeps the range valid for an empty array, where `1..<0` would crash.

## Problems with the naive solution

When most elements have no greater element ahead, or it's far away, each one scans almost the whole array: **O(n²)**. A list of 10,000 equal values does about 10^8 comparisons to return all -1s.

## Optimized solution

Run the monotonic-stack loop for `2n` steps, using `step % n` as the index. During the first n steps, it works exactly like the non-circular version: pop every waiting index whose value is smaller than the current one, record the answer, then push the current index. During the second n steps, it only pops: the elements still waiting get to compare against the elements before them, in the order they'd come after wrapping. Nothing is pushed on the second lap, because every index already had its turn.

## Line by line

- `var answers = Array(repeating: -1, count: count)`: anything never popped keeps -1.
- `var waiting: [Int] = []`: indexes waiting for a greater value. Their values decrease from bottom to top, so the smallest are on top.
- `for step in 0..<(2 * count)`: two laps without copying the array. For an empty array the range is empty.
- `let index = step % count`: on the second lap, step n maps back to index 0.
- `while let last = waiting.last, values[last] < value`: pop every waiting index the current value beats. `<` is strict, so an equal value doesn't resolve it.
- `answers[last] = value` and `waiting.removeLast()`: record the answer and stop waiting.
- `if step < count { waiting.append(index) }`: push only on the first lap. On the second lap every element has already been pushed once, and its answer is either recorded or still waiting on the stack. A second copy would only repeat comparisons that can't change anything.

Each index is pushed once and popped at most once, and each of the 2n steps does one comparison that ends its `while` loop: **O(n) time**. The stack and the result are **O(n) space**.

An element that's the maximum (or tied for it) is never popped, which is why it keeps -1. A one-element array is pushed, then compared with itself on the second lap, and `<` keeps it from answering itself.

## Common mistakes

- Concatenating the array with itself (`values + values`). It works but allocates 2n elements and returns a result twice as long that you then have to trim.
- Pushing on the second lap too. The answers come out the same, but it doubles the stack work, and in an interview it signals you haven't worked out what the second lap is for.
- Using `<=` in the pop condition, so an equal value counts as greater.
- Returning distances measured with `step - last` without adjusting for the wrap. On the second lap, `step` is already the unwrapped position, so `step - last` is the right distance; `index - last` would be negative.

## Variation

**Distances on a circle**: return how many steps ahead the warmer slot is. Store `step - last` instead of `value` when popping. Because `step` keeps counting past n on the second lap, the subtraction already accounts for the wrap.
