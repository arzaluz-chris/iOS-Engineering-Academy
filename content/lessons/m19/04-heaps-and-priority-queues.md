---
id: m19-l04
title: Heaps and priority queues
description: You store a complete binary tree in an array with index arithmetic, keep the heap property with sift up and sift down, wrap it in a generic PriorityQueue with a custom ordering, build a heap from n elements in O(n) and see why, and use heaps for the two patterns that come up most, the top k elements and merging k sorted sequences.
module: m19
order: 4
level: intermediate
minutes: 75
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m19-l01]
objectives:
  - Define a binary heap as a complete binary tree with the heap property, and store it in an array.
  - Compute parent and child indexes and implement sift up and sift down.
  - Build a generic PriorityQueue whose order is given by a closure, with O(log n) push and pop and O(1) peek.
  - Build a heap from an array in O(n) and explain the argument.
  - Solve top-k problems with a size-k heap in O(n log k) and merge k sorted sequences in O(N log k).
terms:
  - term: Binary heap
    definition: A complete binary tree where every parent is ordered before its children (smaller in a min-heap, larger in a max-heap), usually stored in an array.
  - term: Heap property
    definition: The rule that each node is ordered before its children. It says nothing about the order between siblings or cousins.
  - term: Complete binary tree
    definition: A binary tree where every level is full except possibly the last, which is filled from the left. Its nodes fit in an array with no gaps.
  - term: Priority queue
    definition: An abstract type that hands back the highest-priority element first, whatever order elements were added in. A heap is the usual implementation.
  - term: Sift up and sift down
    definition: Moving an element up (swapping with its parent) or down (swapping with its higher-priority child) until the heap property holds again.
  - term: Heapify
    definition: Turning an arbitrary array into a heap in place by sifting down every parent, from the last one to the root. It runs in O(n).
mastery:
  - Draw the tree for a heap stored in an array, and check whether an array is a valid heap.
  - Implement push and pop with sift up and sift down, and state their O(log n) cost.
  - Write a generic PriorityQueue with a comparison closure and use it as a min-heap, a max-heap and with a custom key.
  - Explain why bottom-up heapify is O(n) while n pushes are O(n log n).
  - Find the top k elements with a min-heap of size k, and merge k sorted arrays with a heap of cursors.
resources: [swift-array, swift-book-generics, swift-book-closures, swift-book-protocols]
cards:
  - id: m19-l04-c1
    front: In an array-backed binary heap, what are the indexes of the children and the parent of index i?
    back: "Children at 2i + 1 and 2i + 2, parent at (i − 1) / 2 with integer division. The root is at 0."
  - id: m19-l04-c2
    front: What does the heap property guarantee, and what doesn't it?
    back: "Each parent is ordered before its children, so the top is the minimum (or maximum). It doesn't order siblings, and the array as a whole isn't sorted."
  - id: m19-l04-c3
    front: Why is building a heap bottom-up O(n) and not O(n log n)?
    back: "Sift-down cost depends on a node's height, and most nodes are near the bottom: about n/2 leaves cost nothing, n/4 nodes cost at most 1 level, n/8 at most 2, and so on. The sum n·(1/4 + 2/8 + 3/16 + …) is less than n."
  - id: m19-l04-c4
    front: How do you find the k largest of n elements with a heap, and at what cost?
    back: "Keep a min-heap of at most k elements. Push each element; if the size exceeds k, pop the smallest. The heap ends up with the k largest. O(n log k) time, O(k) space."
  - id: m19-l04-c5
    front: How do you merge k sorted arrays with a heap?
    back: "Put the first element of each array into a min-heap, with its array index and position. Repeatedly pop the smallest, output it, and push the next element from the same array. O(N log k) for N total elements."
---

## The idea in one sentence

A heap is a binary tree packed into an array that always knows its smallest (or largest) element, and keeps knowing it after each insert or removal for O(log n) work, which is what a priority queue needs.

## What a priority queue is

A queue from Module 17 hands elements back in arrival order. A **priority queue** hands back the **most urgent** element first, whatever order they arrived in. Downloads with a priority, timers ordered by fire date, the next event in a simulation, the closest unvisited node in a shortest-path search: they all want "give me the minimum, then let me add more".

The obvious implementations each make one operation slow:

| Implementation | Insert | Remove the minimum |
| --- | --- | --- |
| Unsorted array | O(1) append | O(n) scan |
| Sorted array | O(n) to shift into place | O(1) from the end |
| Binary heap | O(log n) | O(log n) |

A heap gives up the full sort, which nobody asked for, and keeps just enough order to find the minimum.

## The shape and the rule

A **binary heap** is a binary tree with two properties:

1. **Shape**: it's a **complete** binary tree. Every level is full except possibly the last, which fills from the left.
2. **Heap property**: in a **min-heap**, every parent is less than or equal to its children. (In a **max-heap**, greater than or equal.)

So the root is the minimum. Nothing else is promised: siblings can be in any order, and a value on level 3 can be smaller than one on level 1 in a different branch.

```text
            1                 index:  0  1  2  3  4  5  6  7
         /     \              value:  1  3  2  7  4  9  5  8
        3       2
       / \     / \
      7   4   9   5
     /
    8
```

Because the tree is complete, its nodes fit in an array **with no gaps**, level by level, left to right. No child pointers are needed: for the node at index `i`,

- its left child is at `2i + 1`, its right child at `2i + 2`,
- its parent is at `(i − 1) / 2` (integer division).

Check it: 3 is at index 1; its children are at 3 and 4 (7 and 4); its parent is at (1 − 1) / 2 = 0. The 8 at index 7 has parent (7 − 1) / 2 = 3, which holds 7. One array, no node objects, and the height of a complete tree with n nodes is ⌊log₂ n⌋.

## Push: append and sift up

To insert, put the new element in the only place that keeps the tree complete, the end of the array, and then fix the heap property on the path to the root: while the element is smaller than its parent, swap them. That's **sift up**.

## Pop: move the last to the top and sift down

To remove the minimum, take the root. The hole has to be filled while keeping the tree complete, so move the **last** element to the root and shrink the array. That element is probably too big for the top, so **sift down**: while it's larger than its smaller child, swap it with that child. Swapping with the **smaller** child matters: that child becomes the parent of the other one, so it has to be the smaller of the two.

Both walk one root-to-leaf path: **O(log n)**.

```swift
struct MinHeap {
    private(set) var storage: [Int] = []

    var isEmpty: Bool { storage.isEmpty }
    var min: Int? { storage.first }

    mutating func push(_ value: Int) {
        storage.append(value)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            if storage[child] >= storage[parent] { break }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Int? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let smallest = storage.removeLast()
        var parent = 0
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var smallestIndex = parent
            if left < storage.count && storage[left] < storage[smallestIndex] { smallestIndex = left }
            if right < storage.count && storage[right] < storage[smallestIndex] { smallestIndex = right }
            if smallestIndex == parent { break }
            storage.swapAt(parent, smallestIndex)
            parent = smallestIndex
        }
        return smallest
    }
}

var heap = MinHeap()
for value in [5, 3, 8, 1, 9, 2] {
    heap.push(value)
    print("push", value, heap.storage)
}
while let value = heap.pop() {
    print("pop", value, heap.storage)
}
```

```output
push 5 [5]
push 3 [3, 5]
push 8 [3, 5, 8]
push 1 [1, 3, 8, 5]
push 9 [1, 3, 8, 5, 9]
push 2 [1, 3, 2, 5, 9, 8]
pop 1 [2, 3, 8, 5, 9]
pop 2 [3, 5, 8, 9]
pop 3 [5, 9, 8]
pop 5 [8, 9]
pop 8 [9]
pop 9 []
```

1. `push` appends and then compares the new element with its parent, swapping upward until the parent is smaller or it reaches the root. Pushing 1: it lands at index 3, its parent (index 1) is 5, swap; now at index 1, its parent is 3, swap; now at the root.
2. `pop` swaps the root with the last element and removes the last, so `removeLast()` (O(1)) does the removal instead of an O(n) `removeFirst()`.
3. Sift down looks at both children, picks the smaller one if it's smaller than the parent, and swaps. It stops when neither child is smaller, or when there are no children.
4. The array is never sorted (`[1, 3, 2, 5, 9, 8]`), but the pops come out in increasing order. Popping everything is **heap sort**: O(n log n).

## A generic priority queue

Real elements aren't plain integers: a download has a priority, a timer has a fire date. Make the heap generic and let the caller say what "comes first" means, with a closure like the one `sorted(by:)` takes:

```swift
struct PriorityQueue<Element> {
    private var storage: [Element] = []
    private let comesFirst: (Element, Element) -> Bool

    init(by comesFirst: @escaping (Element, Element) -> Bool) {
        self.comesFirst = comesFirst
    }

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }
    var peek: Element? { storage.first }

    mutating func push(_ element: Element) {
        storage.append(element)
        siftUp(from: storage.count - 1)
    }

    mutating func pop() -> Element? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let top = storage.removeLast()
        siftDown(from: 0)
        return top
    }

    private mutating func siftUp(from index: Int) {
        var child = index
        while child > 0 {
            let parent = (child - 1) / 2
            guard comesFirst(storage[child], storage[parent]) else { return }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    private mutating func siftDown(from index: Int) {
        var parent = index
        while true {
            let left = 2 * parent + 1
            let right = left + 1
            var first = parent
            if left < storage.count && comesFirst(storage[left], storage[first]) { first = left }
            if right < storage.count && comesFirst(storage[right], storage[first]) { first = right }
            if first == parent { return }
            storage.swapAt(parent, first)
            parent = first
        }
    }
}

struct Download {
    let name: String
    let priority: Int
}

var maxHeap = PriorityQueue<Int>(by: >)
for value in [4, 9, 1, 7] { maxHeap.push(value) }
print(maxHeap.pop() ?? -1, maxHeap.pop() ?? -1, maxHeap.count)

var downloads = PriorityQueue<Download>(by: { $0.priority > $1.priority })
downloads.push(Download(name: "thumbnail", priority: 3))
downloads.push(Download(name: "analytics", priority: 1))
downloads.push(Download(name: "avatar", priority: 5))
downloads.push(Download(name: "full image", priority: 4))
while let next = downloads.pop() {
    print(next.priority, next.name)
}
```

```output
9 7 2
5 avatar
4 full image
3 thumbnail
1 analytics
```

1. `comesFirst(a, b)` returns `true` when `a` should be closer to the top than `b`. Passing `<` gives a min-heap, `>` a max-heap, and a closure over a property orders by that key. Operators like `>` can be passed directly as functions.
2. The closure is `@escaping` because the initializer stores it for later calls.
3. Sift up and sift down are the integer versions with `<` replaced by `comesFirst`.
4. `peek` is O(1); `push` and `pop` are O(log n).

> [!warning] A heap isn't stable
> Elements with equal priority can come out in any order, not in insertion order. If ties must be broken by arrival time, store a sequence number with each element and compare it when priorities are equal.

> [!note] In production
> The Swift standard library has no heap or priority queue. Apple's open-source [swift-collections](https://github.com/apple/swift-collections) package includes a `Heap` type, added with Swift Package Manager. In interviews you write your own, and the version above is about the size interviewers expect.

## Building a heap in O(n)

Given n elements up front, you could push them one by one: n pushes at O(log n) each, O(n log n). There's a faster way, **heapify**: put the elements in the array as they are, then sift **down** every node that has children, starting from the last parent and moving back to the root.

Why that works: leaves are already one-element heaps. When you sift down node i, both of its subtrees are already heaps (you processed them first, because their indexes are larger), so sifting i down makes the subtree at i a heap too. When you reach the root, the whole array is a heap.

Why it's **O(n)**: the cost of sifting a node down is at most its **height**, and most nodes are near the bottom. In a complete tree about n/2 nodes are leaves (height 0, no work), about n/4 have height 1, n/8 have height 2, and in general about n/2^(h+1) nodes have height h. The total work is at most

> n · (0/2 + 1/4 + 2/8 + 3/16 + 4/32 + …) = n · Σ h / 2^(h+1)

and that series sums to 1, so the total is at most about n swaps. Pushing one by one has the opposite profile: the n/2 elements that end up in the bottom level can each sift up the full height, log n.

You can see the difference by counting swaps when building a max-heap from ascending input, which is the worst case for pushes (every new element is the largest and climbs to the root):

```swift
func siftDown(_ a: inout [Int], from index: Int, count: Int, swaps: inout Int) {
    var parent = index
    while true {
        let left = 2 * parent + 1
        let right = left + 1
        var largest = parent
        if left < count && a[left] > a[largest] { largest = left }
        if right < count && a[right] > a[largest] { largest = right }
        if largest == parent { return }
        a.swapAt(parent, largest)
        swaps += 1
        parent = largest
    }
}

func heapify(_ a: inout [Int]) -> Int {
    var swaps = 0
    var index = a.count / 2 - 1
    while index >= 0 {
        siftDown(&a, from: index, count: a.count, swaps: &swaps)
        index -= 1
    }
    return swaps
}

func buildByPushing(_ values: [Int]) -> Int {
    var heap: [Int] = []
    var swaps = 0
    for value in values {
        heap.append(value)
        var child = heap.count - 1
        while child > 0 && heap[child] > heap[(child - 1) / 2] {
            heap.swapAt(child, (child - 1) / 2)
            swaps += 1
            child = (child - 1) / 2
        }
    }
    return swaps
}

for n in [1_023, 65_535, 1_048_575] {
    var values = Array(1...n)
    let pushSwaps = buildByPushing(values)
    let heapifySwaps = heapify(&values)
    print(n, pushSwaps, heapifySwaps, values[0] == n)
}
```

```output
1023 8194 1013 true
65535 917506 65519 true
1048575 18874370 1048555 true
```

For about a million elements, pushing costs about 18.9 million swaps (roughly n log₂ n), while heapify stays under n. The last column is the check that the maximum ended up at the root.

1. The last node with children is at `count / 2 - 1`; everything after it is a leaf.
2. The loop runs **backward**, so each node's subtrees are heaps before it's sifted.

The asymptotic difference rarely matters in app code, since you'd sort or push at O(n log n) and be fine. It matters in interviews ("can you do better than n log n to build it?") and it's a good example of an analysis where the obvious bound, n nodes times log n each, isn't tight.

## Pattern: the top k

"The 10 most played songs", "the 5 closest stores", "the k largest files". Sorting everything is O(n log n). With a heap you can do **O(n log k)** with O(k) memory, which matters when n is large or the data streams in.

The trick is counterintuitive: to keep the k **largest**, use a **min**-heap of size k. Its top is the smallest of the current top k, the one to evict when something bigger comes along.

```swift
struct PriorityQueue<Element> {
    private var storage: [Element] = []
    private let comesFirst: (Element, Element) -> Bool
    init(by comesFirst: @escaping (Element, Element) -> Bool) { self.comesFirst = comesFirst }
    var count: Int { storage.count }
    var peek: Element? { storage.first }

    mutating func push(_ element: Element) {
        storage.append(element)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard comesFirst(storage[child], storage[parent]) else { return }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Element? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let top = storage.removeLast()
        var parent = 0
        while true {
            let left = 2 * parent + 1, right = left + 1
            var first = parent
            if left < storage.count && comesFirst(storage[left], storage[first]) { first = left }
            if right < storage.count && comesFirst(storage[right], storage[first]) { first = right }
            if first == parent { break }
            storage.swapAt(parent, first)
            parent = first
        }
        return top
    }
}

func topSongs(_ plays: [String], k: Int) -> [(String, Int)] {
    var counts: [String: Int] = [:]
    for song in plays { counts[song, default: 0] += 1 }

    let lessPopular: ((String, Int), (String, Int)) -> Bool = { a, b in
        a.1 != b.1 ? a.1 < b.1 : a.0 > b.0
    }
    var heap = PriorityQueue<(String, Int)>(by: lessPopular)
    for entry in counts {
        heap.push((entry.key, entry.value))
        if heap.count > k { _ = heap.pop() }
    }

    var result: [(String, Int)] = []
    while let entry = heap.pop() { result.append(entry) }
    return result.reversed()
}

let plays = ["Intro", "Run", "Echo", "Run", "Intro", "Run", "Echo", "Bloom", "Echo", "Drift", "Run"]
for (song, count) in topSongs(plays, k: 3) {
    print(count, song)
}
```

```output
4 Run
3 Echo
2 Intro
```

1. Counting is the frequency pattern from Module 16: O(n).
2. `lessPopular` orders by play count, and on ties by name, reversed, so that among equal counts the alphabetically **later** name is evicted first. Without a tie-breaker the result would depend on dictionary order.
3. For each of the m distinct songs, push and maybe pop: O(log k) each, because the heap never holds more than k + 1 elements. Total O(n + m log k).
4. Popping the final heap gives the top k from least to most popular, so the result is reversed.

When k is close to n, just sort. When k is small and n is huge, or the elements arrive one at a time, the heap wins.

## Pattern: merging k sorted sequences

You have k sorted arrays (sorted pages from k servers, k sorted log files) and want one sorted result. Comparing the fronts of all k arrays at every step costs O(k) per element. A min-heap of **cursors**, one per array, finds the smallest front in O(log k):

```swift
struct PriorityQueue<Element> {
    private var storage: [Element] = []
    private let comesFirst: (Element, Element) -> Bool
    init(by comesFirst: @escaping (Element, Element) -> Bool) { self.comesFirst = comesFirst }

    mutating func push(_ element: Element) {
        storage.append(element)
        var child = storage.count - 1
        while child > 0 {
            let parent = (child - 1) / 2
            guard comesFirst(storage[child], storage[parent]) else { return }
            storage.swapAt(child, parent)
            child = parent
        }
    }

    mutating func pop() -> Element? {
        guard !storage.isEmpty else { return nil }
        storage.swapAt(0, storage.count - 1)
        let top = storage.removeLast()
        var parent = 0
        while true {
            let left = 2 * parent + 1, right = left + 1
            var first = parent
            if left < storage.count && comesFirst(storage[left], storage[first]) { first = left }
            if right < storage.count && comesFirst(storage[right], storage[first]) { first = right }
            if first == parent { break }
            storage.swapAt(parent, first)
            parent = first
        }
        return top
    }
}

struct Cursor {
    let value: Int
    let list: Int
    let index: Int
}

func mergeSorted(_ lists: [[Int]]) -> [Int] {
    var heap = PriorityQueue<Cursor>(by: { $0.value < $1.value })
    for (list, values) in lists.enumerated() where !values.isEmpty {
        heap.push(Cursor(value: values[0], list: list, index: 0))
    }
    var merged: [Int] = []
    while let smallest = heap.pop() {
        merged.append(smallest.value)
        let nextIndex = smallest.index + 1
        if nextIndex < lists[smallest.list].count {
            heap.push(Cursor(value: lists[smallest.list][nextIndex], list: smallest.list, index: nextIndex))
        }
    }
    return merged
}

print(mergeSorted([[1, 4, 9], [2, 3, 10, 11], [], [0, 5]]))
```

```output
[0, 1, 2, 3, 4, 5, 9, 10, 11]
```

The heap never holds more than one cursor per list, so it has at most k elements. Each of the N output elements costs one pop and at most one push: **O(N log k)** time and O(k) extra space besides the output. Concatenating and sorting would be O(N log N), and it would ignore the fact that the inputs were already sorted.

## Common mistakes

> [!error] Sifting down toward the wrong child
> In a min-heap, swap with the **smaller** child. If you swap with the left child when the right one is smaller, the left child's value becomes the parent of a smaller value and the heap property breaks.

> [!error] Forgetting the right-child bounds check
> A node can have a left child and no right child. Check `right < storage.count` before reading it, or the pop crashes with Index out of range.

> [!error] Removing the root with removeFirst()
> That shifts the whole array, O(n), and scrambles every parent-child relationship. Swap the root with the last element, `removeLast()`, then sift down.

> [!error] Using a max-heap for the k largest
> A max-heap of all n elements works but costs O(n) memory and O(n + k log n). The size-k trick needs a min-heap, so the smallest of the current winners is the one you can evict.

> [!error] Heapifying from the root forward
> Sifting down only works if the node's subtrees are already heaps. Go from `count / 2 - 1` down to 0.

## Exercises

````exercise
id: m19-l04-e1
type: comprehension
prompt: Which of these arrays is a valid min-heap?
choices:
  - text: "[1, 2, 3, 4, 5, 0]"
    correct: false
    why: 0 is at index 5, whose parent at index 2 holds 3. A child is smaller than its parent.
  - text: "[2, 5, 3, 6, 9, 4, 8]"
    correct: true
    why: "Index 0 (2) ≤ 5 and 3; index 1 (5) ≤ 6 and 9; index 2 (3) ≤ 4 and 8. Every parent is at most its children."
  - text: "[3, 1, 4, 5, 9]"
    correct: false
    why: The root 3 is larger than its left child 1.
  - text: "[1, 4, 2, 3, 6]"
    correct: false
    why: "Index 3 holds 3, whose parent at index 1 holds 4."
solution: |
  **[2, 5, 3, 6, 9, 4, 8].** For each index i that has children, compare it with 2i + 1 and 2i + 2. Here that's indexes 0, 1 and 2, and each parent is ≤ its children. The array isn't sorted, and doesn't need to be: 5 is before 3, and 6 is before 4, but those pairs are not parent and child. In the last option, the violation is two levels down: 3 at index 3 is a child of 4 at index 1, even though it's larger than the root.
````

````exercise
id: m19-l04-e2
type: prediction
prompt: "Predict the exact output: the heap's array after the pushes, then after one pop."
code: |
  func push(_ value: Int, into heap: inout [Int]) {
      heap.append(value)
      var child = heap.count - 1
      while child > 0 && heap[child] < heap[(child - 1) / 2] {
          heap.swapAt(child, (child - 1) / 2)
          child = (child - 1) / 2
      }
  }

  func pop(_ heap: inout [Int]) -> Int {
      heap.swapAt(0, heap.count - 1)
      let top = heap.removeLast()
      var parent = 0
      while true {
          let left = 2 * parent + 1, right = left + 1
          var smallest = parent
          if left < heap.count && heap[left] < heap[smallest] { smallest = left }
          if right < heap.count && heap[right] < heap[smallest] { smallest = right }
          if smallest == parent { break }
          heap.swapAt(parent, smallest)
          parent = smallest
      }
      return top
  }

  var heap: [Int] = []
  for value in [6, 4, 7, 2, 5] {
      push(value, into: &heap)
  }
  print(heap)
  print(pop(&heap), heap)
output: |
  [2, 4, 7, 6, 5]
  2 [4, 5, 7, 6]
hints:
  - "After 6, 4: 4 sifts up to the root, [4, 6]. Then 7 stays at index 2."
  - 2 lands at index 3 (parent index 1, holding 6), swaps, then swaps with the root.
  - "On pop, 5 moves to the root and sifts down toward the smaller child."
solution: |
  ```output
  [2, 4, 7, 6, 5]
  2 [4, 5, 7, 6]
  ```

  Pushes: `[6]`; 4 swaps with 6 → `[4, 6]`; 7 stays → `[4, 6, 7]`; 2 at index 3 swaps with 6 (index 1), then with 4 (index 0) → `[2, 4, 7, 6]`; 5 at index 4 has parent 4 (index 1), no swap → `[2, 4, 7, 6, 5]`.

  Pop: swap 2 with the last element 5 and remove it → `[5, 4, 7, 6]`. Sift down 5: children 4 and 7, the smaller is 4, swap → `[4, 5, 7, 6]`. Now 5 is at index 1, its only child is 6 (index 3), no swap. The pop returns 2.
````

````exercise
id: m19-l04-e3
type: fill-in
prompt: Complete heapify for a min-heap so the program prints `[1, 2, 3, 4, 9, 7, 5]`.
code: |
  func siftDown(_ a: inout [Int], from index: Int) {
      var parent = index
      while true {
          let left = 2 * parent + 1
          let right = left + 1
          var smallest = parent
          if left < a.count && a[left] < a[smallest] { smallest = left }
          if right < a.count && a[right] < a[smallest] { smallest = right }
          if smallest == [[1]] { return }
          a.swapAt(parent, smallest)
          parent = [[2]]
      }
  }

  func heapify(_ a: inout [Int]) {
      var index = a.count / 2 - [[3]]
      while index >= 0 {
          siftDown(&a, from: index)
          index -= 1
      }
  }

  var values = [9, 4, 7, 1, 2, 3, 5]
  heapify(&values)
  print(values)
blanks:
  - id: "1"
    answers: ["parent"]
  - id: "2"
    answers: ["smallest"]
  - id: "3"
    answers: ["1"]
solution: |
  ```swift
  func siftDown(_ a: inout [Int], from index: Int) {
      var parent = index
      while true {
          let left = 2 * parent + 1
          let right = left + 1
          var smallest = parent
          if left < a.count && a[left] < a[smallest] { smallest = left }
          if right < a.count && a[right] < a[smallest] { smallest = right }
          if smallest == parent { return }
          a.swapAt(parent, smallest)
          parent = smallest
      }
  }

  func heapify(_ a: inout [Int]) {
      var index = a.count / 2 - 1
      while index >= 0 {
          siftDown(&a, from: index)
          index -= 1
      }
  }

  var values = [9, 4, 7, 1, 2, 3, 5]
  heapify(&values)
  print(values)
  ```

  ```output
  [1, 2, 3, 4, 9, 7, 5]
  ```

  Sift-down stops when the parent is already the smallest of the three, and otherwise follows the element down to the child it swapped with. Heapify starts at the last node with children, `count / 2 - 1` = 2 for seven elements: 7 swaps with 3. Index 1: 4 swaps with 1. Index 0: 9 swaps with 1, then with 2. Each subtree is a heap before its parent is sifted, which is why the loop goes backward.
````

````exercise
id: m19-l04-e4
type: solve
prompt: |
  A game shows "you're in the top k" by tracking the k-th highest score seen so far. Write a `KthHighest` struct with `init(k: Int)` and `mutating func add(_ score: Int) -> Int?` that records a score and returns the current k-th highest score, or `nil` while fewer than k scores have arrived. Each `add` must be O(log k), and memory O(k).

  Expected output for the starter's calls:

  ```output
  nil nil 4 4 4 5 8
  ```
starter: |
  struct KthHighest {
      init(k: Int) {
      }

      mutating func add(_ score: Int) -> Int? {
          return nil
      }
  }

  var tracker = KthHighest(k: 3)
  let results = [4, 5, 8, 2, 3, 9, 10].map { tracker.add($0) }
  print(results.map { $0.map(String.init) ?? "nil" }.joined(separator: " "))
hints:
  - Keep only the k highest scores so far, in a min-heap.
  - The k-th highest is the smallest of those, the top of the min-heap.
  - When a new score arrives and the heap has k elements, it only matters if it's bigger than the top.
rubric:
  - Keeps a min-heap of at most k scores.
  - Returns the heap's minimum once it holds k scores, and nil before.
  - Implements push and pop (or replace-top) with sift up and sift down.
  - "States the costs: O(log k) per add, O(k) memory."
solution: |
  ```swift
  struct KthHighest {
      private let k: Int
      private var heap: [Int] = []

      init(k: Int) {
          self.k = k
      }

      mutating func add(_ score: Int) -> Int? {
          if heap.count < k {
              heap.append(score)
              var child = heap.count - 1
              while child > 0 && heap[child] < heap[(child - 1) / 2] {
                  heap.swapAt(child, (child - 1) / 2)
                  child = (child - 1) / 2
              }
          } else if score > heap[0] {
              heap[0] = score
              var parent = 0
              while true {
                  let left = 2 * parent + 1, right = left + 1
                  var smallest = parent
                  if left < heap.count && heap[left] < heap[smallest] { smallest = left }
                  if right < heap.count && heap[right] < heap[smallest] { smallest = right }
                  if smallest == parent { break }
                  heap.swapAt(parent, smallest)
                  parent = smallest
              }
          }
          return heap.count == k ? heap[0] : nil
      }
  }

  var tracker = KthHighest(k: 3)
  let results = [4, 5, 8, 2, 3, 9, 10].map { tracker.add($0) }
  print(results.map { $0.map(String.init) ?? "nil" }.joined(separator: " "))
  ```

  ```output
  nil nil 4 4 4 5 8
  ```

  The heap holds the k highest scores seen so far, and its top is the smallest of them, which is exactly the k-th highest. Until it has k scores there's no answer. After 4, 5 and 8 the answer is 4. A new score that isn't larger than the top (2, then 3) can't enter the top k, so nothing changes. A larger one (9) **replaces** the top and sifts down, which is a pop and a push in one step: the top three become 5, 8, 9 and the answer is 5. Then 10 evicts 5, and the answer is 8.

  Each `add` does at most one sift, over a heap of at most k elements: **O(log k)** time and **O(k)** memory, no matter how many scores arrive. Keeping every score in a max-heap would also work but would grow without bound.
````

````exercise
id: m19-l04-e5
type: explain
prompt: |
  A teammate says: "Building a heap from n elements is n sift-downs, and each sift-down is O(log n), so heapify is O(n log n). The O(n) claim must be wrong." Explain where the reasoning goes wrong and give the real bound with the argument.
code: |
  func heapify(_ a: inout [Int]) {
      var index = a.count / 2 - 1
      while index >= 0 {
          siftDown(&a, from: index)
          index -= 1
      }
  }
rubric:
  - Agrees that each sift-down is O(log n) in the worst case, so O(n log n) is a valid upper bound but not tight.
  - Explains that a sift-down costs at most the node's height, not the tree's height.
  - Counts nodes per height (about n/2^(h+1) at height h) and sums n · Σ h/2^(h+1).
  - States that the sum is bounded by a constant times n, so heapify is O(n).
  - Contrasts with pushing one by one, where the many bottom nodes can each move up the full height.
solution: |
  The bound O(n log n) is **true but not tight**. The mistake is charging every node the height of the whole tree. A sift-down starting at a node can only move down as far as the bottom, so it costs at most that node's **height**, and in a complete tree most nodes have small height.

  About n/2 nodes are leaves and are never sifted. About n/4 have height 1 and move at most one level, about n/8 move at most two, and in general about n/2^(h+1) nodes have height h. So the total work is at most n · (1/4 + 2/8 + 3/16 + …) = n · Σ h/2^(h+1). That series converges to 1, so heapify does at most about n swaps: **O(n)**.

  The intuition: heapify does the expensive work (long sift-downs) only for the few nodes near the top. Pushing one at a time is the reverse: the n/2 elements that end up at the bottom can each sift **up** the full log n levels, which is where n log n really comes from. The lesson's swap counts show it: about a million elements took about 18.9 million swaps by pushing and fewer than a million with heapify.
````

## Summary

- A **priority queue** returns the most urgent element first. A **binary heap** implements it with O(log n) push and pop and O(1) peek.
- A heap is a **complete** binary tree with the **heap property** (each parent before its children), stored in an array: children of i at 2i + 1 and 2i + 2, parent at (i − 1) / 2.
- **Push** appends and sifts up. **Pop** swaps the root with the last element, removes it, and sifts down toward the higher-priority child.
- A generic `PriorityQueue` takes a `comesFirst` closure: `<` for a min-heap, `>` for a max-heap, or a comparison on a key. Heaps aren't stable; add a tie-breaker when it matters.
- **Heapify** sifts down from `count / 2 - 1` to 0 and runs in **O(n)**, because a sift-down costs the node's height and most nodes are low.
- **Top k**: a min-heap of size k, O(n log k). **Merge k sorted**: a min-heap of cursors, O(N log k).
