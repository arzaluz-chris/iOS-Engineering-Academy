---
id: min-stack
title: Min Stack
difficulty: medium
order: 25
patterns: [Stack, Augmented data structure]
prerequisites: [m17-l01]
summary: Build a stack that can also tell you its smallest element in O(1). The trick is storing a little extra with every push.
solutionFile: MinStack.swift
testFile: MinStackTests.swift
starter: |
  struct MinStack {
      init() {}

      var isEmpty: Bool { true }

      func top() -> Int? {
          nil
      }

      func minimum() -> Int? {
          nil
      }

      mutating func push(_ value: Int) {
          // Your solution
      }

      @discardableResult
      mutating func pop() -> Int? {
          nil
      }
  }
time: O(1) per operation (push amortized)
space: O(n)
edgeCases:
  - Every query on an empty stack, which returns nil
  - The same minimum pushed twice, then popped once
  - Popping the current minimum, so the previous one has to come back
  - Int.min and Int.max as values
askInterviewer:
  - What should pop, top and minimum do on an empty stack? Return nil, or is that a precondition?
  - Is O(1) required for every operation, or only for minimum?
  - Can values repeat?
hints:
  - Keeping one variable with the current minimum works for push. What goes wrong when you pop the element that was the minimum?
  - When the stack has k elements, its minimum depends only on those k elements. Could you store that answer at the moment the k-th element is pushed?
  - Store a pair with each push. What's the second half of the pair?
followUps:
  - Can you use less memory when the minimum rarely changes? (Keep a second stack that only gets a push when the new value is less than or equal to its top.)
  - How would you also support maximum?
  - How would you build a queue that reports its minimum in O(1) amortized? (Two min stacks, as in the two-stack queue from lesson m17-l02.)
rubric:
  - I explained why a single "current minimum" variable breaks on pop.
  - I stored the minimum so far alongside each element, so pop restores the previous minimum for free.
  - I handled the empty stack without crashing.
  - I gave O(1) per operation and O(n) space, and mentioned the second-stack variant that saves memory.
codeStatus: tested
---

A drawing app keeps a stack of brush sizes as the user nests tool settings, and the toolbar shows the smallest size currently on the stack. Design a `MinStack` of integers with:

- `push(_ value: Int)`: add a value on top.
- `pop() -> Int?`: remove and return the top value, or `nil` if the stack is empty.
- `top() -> Int?`: the top value without removing it, or `nil`.
- `minimum() -> Int?`: the smallest value currently in the stack, or `nil`.
- `isEmpty: Bool`.

Every operation must run in O(1) time.

```swift
var stack = MinStack()
stack.push(5)
stack.push(3)
stack.push(7)
stack.minimum()   // 3
stack.pop()       // 7
stack.minimum()   // 3
stack.pop()       // 3
stack.minimum()   // 5
stack.top()       // 5
```

**Constraints:** up to 10^5 operations; values are any `Int`.

<!-- reveal -->

## First approach

A stack is easy: an Array with `append` and `popLast()`. The question is what to keep so the minimum is always ready. One variable for the current minimum handles pushes (compare and update), but a pop can remove the minimum, and then you'd have no idea what the previous minimum was. The minimum of the stack's first k elements never changes while those k elements are there, so compute it once, at push time, and keep it with the element.

## Naive solution

A plain stack that scans for the minimum when asked:

```swift
struct MinStack {
    private var values: [Int] = []

    var isEmpty: Bool { values.isEmpty }

    func top() -> Int? {
        values.last
    }

    func minimum() -> Int? {
        values.min()
    }

    mutating func push(_ value: Int) {
        values.append(value)
    }

    @discardableResult
    mutating func pop() -> Int? {
        values.popLast()
    }
}
```

## Problems with the naive solution

`minimum()` is **O(n)**: `min()` walks the whole array. If the toolbar reads it after every change, n operations cost O(n²). Caching the minimum in one variable fixes reads but breaks on pop, because the variable can't tell you what the minimum was before the element you just removed.

## Optimized solution

Store each element as a pair: the value, and the minimum of everything from the bottom of the stack up to and including it. Push computes the new pair's minimum from the value and the minimum stored in the current top. Pop just removes the top pair, and the new top already holds the right minimum for the elements left.

## Line by line

- `private var entries: [(value: Int, minimum: Int)] = []`: the stack. Each entry carries its own running minimum. A named tuple keeps it short; a small struct would work the same.
- `top()` returns `entries.last?.value` and `minimum()` returns `entries.last?.minimum`: both read the top entry, and optional chaining returns `nil` on an empty stack. They're methods rather than computed properties to mirror `pop()`; either would be fine.
- `let minimumSoFar = min(value, entries.last?.minimum ?? value)`: the minimum including the new value. On an empty stack, `?? value` makes the value its own minimum, so there's no sentinel like `Int.max` to get wrong.
- `entries.append((value: value, minimum: minimumSoFar))`: push, amortized O(1).
- `entries.popLast()?.value`: pop returns `nil` for an empty stack instead of crashing, and drops the stored minimum along with the value. Nothing else needs updating.
- `@discardableResult` lets callers pop without using the result, like `Stack.pop()` in lesson m17-l01.

## Common mistakes

- Keeping a single `currentMinimum` variable and trying to "recompute" it on pop, which is O(n) again.
- Using `removeLast()`, which stops the program on an empty stack.
- In the two-stack variant, pushing onto the minimum stack only when the value is strictly less than its top. With duplicates of the minimum, the first pop of that value removes it from the minimum stack while a copy is still on the main stack. Use `<=`.
- Starting the minimum at 0 or `Int.max` and comparing, instead of using the first value.

## Variation

**Max stack with popMax**: a stack that can also remove its largest element, wherever it is. The paired-minimum trick no longer helps, since the removed element can be in the middle. The usual answer combines a doubly linked list (for stack order) with a sorted structure or a heap keyed by value, giving O(log n) per operation.
