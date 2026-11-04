---
id: last-stone-weight
title: Last Stone Weight
difficulty: easy
order: 75
patterns: [Heap, Simulation]
prerequisites: [m15, m19-l04]
summary: Repeatedly take the two largest values, combine them and put the result back. Whenever you need "the largest" over and over while the collection changes, reach for a heap.
solutionFile: LastStoneWeight.swift
testFile: LastStoneWeightTests.swift
starter: |
  func lastStoneWeight(_ stones: [Int]) -> Int {
      // Your solution
      return 0
  }
time: O(n log n)
space: O(n)
edgeCases:
  - Empty pile
  - A single stone
  - Two equal stones that destroy each other
  - An odd number of equal stones
askInterviewer:
  - What do I return if no stones are left?
  - Can weights be zero?
  - Can I modify the input?
hints:
  - Each round needs the two largest values. What does it cost to find them by scanning? By sorting?
  - After a round, one new value may go back in. Which structure gives you the largest value, and accepts new ones, in O(log n)?
  - Swift's standard library has no heap type. The Module 19 lesson on heaps builds one in about 30 lines; you can write a max-heap of Int with the same code.
followUps:
  - What if you could choose any two stones each round, and wanted the smallest possible final weight? (It becomes a subset-sum DP problem.)
  - Build the initial heap in O(n) instead of O(n log n). Does it change the total complexity here?
  - The swift-collections package has a `Heap` type. When would you add a dependency for it in an app?
rubric:
  - I identified the need for repeated maximum extraction with insertions.
  - I used a max-heap (or explained how to get one from a min-heap).
  - I gave O(n log n) time and compared it with re-sorting every round.
  - I handled the empty and single-stone cases.
codeStatus: tested
---

A puzzle game has a pile of stones, each with a positive weight. Every turn, the two heaviest stones are smashed together:

- If they weigh the same, both are destroyed.
- Otherwise the lighter one is destroyed, and the heavier one stays with its weight reduced by the lighter one's weight.

This repeats until at most one stone is left. Write `lastStoneWeight(_:)`, which returns the weight of the last stone, or 0 if none is left.

```swift
lastStoneWeight([3, 7, 2, 4])  // 2: 7 and 4 leave 3; 3 and 3 vanish; 2 is left
lastStoneWeight([10, 4, 1])    // 5: 10 and 4 leave 6; 6 and 1 leave 5
lastStoneWeight([5, 5])        // 0
lastStoneWeight([6])           // 6
```

**Constraints:** `0 ≤ stones.count ≤ 10^4`; `1 ≤ weight ≤ 10^4`.

<!-- reveal -->

## First approach

Every turn needs the two largest values, and then one value may go back into the pile. The pile changes all the time, so sorting once isn't enough. This is the situation a priority queue is for: repeated "take the largest" mixed with inserts.

## Naive solution

Sort the pile before every turn and take the last two:

```swift
func lastStoneWeight(_ stones: [Int]) -> Int {
    var pile = stones
    while pile.count > 1 {
        pile.sort()
        let heaviest = pile.removeLast()
        let second = pile.removeLast()
        if heaviest > second {
            pile.append(heaviest - second)
        }
    }
    return pile.first ?? 0
}
```

## Problems with the naive solution

Each turn removes at least one stone, so there are up to n − 1 turns, and each sorts the pile: O(n² log n) in total. Even scanning for the two largest instead of sorting is O(n) per turn, O(n²) overall. With 10^4 stones, that's on the order of 10^8 operations, where a heap needs about 10^5.

## Optimized solution

Put all the stones in a max-heap. Each turn is two pops and at most one push, each O(log n), and there are at most n − 1 turns: O(n log n). Swift's standard library has no heap, so the solution includes a small one, the same array-based design as the Module 19 lesson, with the comparison flipped to keep the largest value on top.

## Line by line

- `var heap = StoneMaxHeap(stones)`: builds the heap with heapify, O(n).
- `while let heaviest = heap.pop()`: the loop ends when the heap is empty.
- `guard let second = heap.pop() else { return heaviest }`: only one stone was left, and that's the answer.
- `if heaviest > second { heap.push(heaviest - second) }`: equal stones push nothing; otherwise the difference goes back. `heaviest` came out first, so it's never smaller than `second`.
- `return 0`: the heap emptied with an even final pair.
- `StoneMaxHeap.init`: sifts down every node that has children, from `count / 2 - 1` back to 0. That's heapify, O(n).
- `push`: append, then sift up while the child is larger than its parent.
- `pop`: swap the root with the last element, remove it, then sift the new root down to the larger child until neither child is larger.

## Common mistakes

- Sorting once at the start and then appending the difference to the end, which breaks the order.
- Using a min-heap by accident. If you only have a min-heap, push negated weights.
- Forgetting the empty case and returning `pile[0]`, which crashes on `[]` and on `[5, 5]`.

## Variation

**K closest points to the origin:** keep a max-heap of size k by distance. For each point, push it, and if the heap has more than k elements, pop the farthest. O(n log k) instead of sorting everything in O(n log n).
