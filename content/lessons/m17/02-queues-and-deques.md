---
id: m17-l02
title: Queues and deques
description: You see why an Array used as a queue with removeFirst() turns an O(n) job into O(n²), build two queues with amortized O(1) dequeue (a head index and a pair of stacks) and prove their cost, then build a ring-buffer deque that adds and removes at both ends, and use a queue to process items in the order they were discovered.
module: m17
order: 2
level: intermediate
minutes: 60
codeStatus: tested
swiftVersion: "6.4"
prerequisites: [m17-l01]
objectives:
  - Define a queue (FIFO) and a deque, and name their operations.
  - Explain why removeFirst() on an Array is O(n) and what that does to a loop.
  - Build a head-index queue and a two-stack queue, and prove that dequeue is amortized O(1).
  - Build a ring-buffer deque with wraparound indexes and growth.
  - Explain why processing items in discovery order with a queue visits them level by level.
terms:
  - term: Queue
    definition: A collection where you add at the back and remove at the front. The first element in is the first one out (FIFO).
  - term: FIFO
    definition: First in, first out. The order in which a queue hands elements back.
  - term: Enqueue and dequeue
    definition: Adding an element at the back of a queue, and removing the element at the front.
  - term: Deque
    definition: A double-ended queue. You can add and remove at both the front and the back.
  - term: Ring buffer
    definition: A fixed-size array used as a circle. Indexes wrap around from the last slot to the first with the remainder operator, so the front can move without shifting elements.
  - term: Amortized analysis
    definition: Bounding the total cost of a sequence of operations and dividing by their number. Some operations can be expensive as long as the total stays small.
mastery:
  - "Spot removeFirst() or remove(at: 0) in a loop and explain the O(n²) cost."
  - Implement a head-index queue that compacts its storage, and argue the amortized O(1) cost.
  - Implement a two-stack queue and explain why each element is moved at most twice.
  - Implement a ring-buffer deque and compute wrapped indexes without going negative.
  - Predict the order in which a queue and a stack process the same items.
resources: [swift-array, swift-book-generics, swift-book-basic-operators, swift-optional]
cards:
  - id: m17-l02-c1
    front: Why is using an Array as a queue with removeFirst() slow?
    back: "removeFirst() shifts every remaining element one place left, which Apple documents as O(n). Dequeuing all n elements this way costs O(n²) in total."
  - id: m17-l02-c2
    front: How does a head-index queue make dequeue O(1)?
    back: "Instead of removing the front element, it reads items[head] and moves head forward. Now and then it drops the used prefix in one O(n) step, which is paid for by the dequeues since the last compaction, so the amortized cost stays O(1)."
  - id: m17-l02-c3
    front: In a two-stack queue, why is dequeue amortized O(1)?
    back: "Each element is pushed onto the inbox once, moved to the outbox once, and popped once. Over n operations that's at most 3n moves, even though a single dequeue that refills the outbox is O(n)."
  - id: m17-l02-c4
    front: How do you move a ring buffer's head one slot backward without a negative index?
    back: "head = (head - 1 + capacity) % capacity. In Swift, % keeps the sign of the left operand, so (0 - 1) % capacity is -1."
  - id: m17-l02-c5
    front: If you process items with a queue, adding newly discovered ones at the back, in what order are they handled?
    back: "In order of discovery, so everything one step from the start comes before anything two steps away. That's breadth-first order. A stack instead goes deep first."
---

## The idea in one sentence

A queue hands elements back in the order they arrived, and the whole trick to building one on an array is **never shifting the elements** when the front leaves.

## What a queue is

A **queue** has two ends: you **enqueue** at the back and **dequeue** from the front. The order is **FIFO**, first in, first out, like a line at a coffee shop. A **deque** (double-ended queue, pronounced "deck") allows both operations at both ends.

Apps are full of queues: uploads waiting for the network, messages to send in order, analytics events to batch, cells to prefetch, and tasks of any kind where fairness means "whoever came first goes first".

## The obvious version and its cost

Append at the back, `removeFirst()` from the front:

```swift
var uploads = ["photo-1", "photo-2", "photo-3"]
uploads.append("photo-4")
while !uploads.isEmpty {
    let next = uploads.removeFirst()
    print("Uploading", next)
}
```

```output
Uploading photo-1
Uploading photo-2
Uploading photo-3
Uploading photo-4
```

It's correct, and Module 15 already told you the problem: Apple documents `removeFirst()` as "O(n), where n is the length of the collection". An array keeps its elements in consecutive memory starting at index 0, so removing the first one moves every other element down a slot. Draining n elements costs (n − 1) + (n − 2) + … + 0 moves, which is **O(n²)**.

For a handful of uploads that doesn't matter. For a queue that processes 100,000 events, it's about 5 billion element moves. The two queues below keep the array but stop shifting it.

## Queue 1: a head index

Don't remove the front element. Remember where the front is.

```swift
struct Queue<Element> {
    private var items: [Element] = []
    private var head = 0

    var isEmpty: Bool { head == items.count }
    var count: Int { items.count - head }
    var front: Element? { isEmpty ? nil : items[head] }

    mutating func enqueue(_ element: Element) {
        items.append(element)
    }

    mutating func dequeue() -> Element? {
        guard head < items.count else { return nil }
        let element = items[head]
        head += 1
        if head >= 16 && head * 2 >= items.count {
            items.removeFirst(head)
            head = 0
        }
        return element
    }
}

var queue = Queue<String>()
for name in ["photo-1", "photo-2", "photo-3"] {
    queue.enqueue(name)
}
print(queue.dequeue() ?? "none", queue.count)
queue.enqueue("photo-4")
while let next = queue.dequeue() {
    print("Uploading", next)
}
print(queue.isEmpty, queue.dequeue() ?? "none")
```

```output
photo-1 2
Uploading photo-2
Uploading photo-3
Uploading photo-4
true none
```

1. `items[head..<items.count]` holds the queue. Everything before `head` was already dequeued.
2. `dequeue` reads `items[head]` and moves `head` forward. No element moves: O(1).
3. Without cleanup, the used prefix would keep growing, and with it memory: a queue that has seen a million elements would keep all of them, even if only three are waiting. So once the used prefix is at least half the array (and at least 16 elements, to skip tiny arrays), `removeFirst(head)` drops it in one go and `head` resets to 0.

**Why that's still O(1) amortized.** The compaction is O(n): it moves the elements still waiting to the front. But it only runs when `head` is at least half of `items.count`, so the number of elements moved is at most `head`, and each of those `head` dequeues happened since the last compaction. Charge each dequeue for at most one moved element and every compaction is already paid for. Over any sequence of operations, the total work is O(number of operations), even though one particular dequeue costs O(n).

That's the same argument as Array's own `append` in Module 15: expensive steps that get rarer in proportion to how much cheap work came before.

## Queue 2: two stacks

A second classic design uses two stacks, an **inbox** and an **outbox**. Enqueue pushes onto the inbox. Dequeue pops from the outbox, and when the outbox is empty, it first moves everything from the inbox to the outbox, which reverses the order. The oldest element ends up on top.

```swift
struct TwoStackQueue<Element> {
    private var inbox: [Element] = []
    private var outbox: [Element] = []

    var isEmpty: Bool { inbox.isEmpty && outbox.isEmpty }

    mutating func enqueue(_ element: Element) {
        inbox.append(element)
    }

    mutating func dequeue() -> Element? {
        if outbox.isEmpty {
            while let element = inbox.popLast() {
                outbox.append(element)
            }
        }
        return outbox.popLast()
    }
}

var messages = TwoStackQueue<String>()
messages.enqueue("A")
messages.enqueue("B")
messages.enqueue("C")
print(messages.dequeue() ?? "-")
messages.enqueue("D")
print(messages.dequeue() ?? "-", messages.dequeue() ?? "-", messages.dequeue() ?? "-")
print(messages.dequeue() ?? "-")
```

```output
A
B C D
-
```

Trace it:

| Step | inbox (bottom → top) | outbox (bottom → top) | Returns |
| --- | --- | --- | --- |
| enqueue A, B, C | A B C | | |
| dequeue | | C B | A (moved 3, popped A) |
| enqueue D | D | C B | |
| dequeue | D | C | B |
| dequeue | D | | C |
| dequeue | | | D (moved 1, popped D) |

Notice that D waited in the inbox while B and C left: the outbox is only refilled when it's **empty**. Refilling while it still has elements would put D on top of B and break the order.

**The amortized argument** is short: every element is pushed onto the inbox once, moved to the outbox once, and popped once. Three O(1) steps per element, so n enqueues and n dequeues cost O(n) in total, **O(1) amortized** per operation. A single dequeue can still cost O(n) when it triggers a refill.

> [!note] Which one to use
> Both are amortized O(1). The head-index queue is simpler and keeps elements in arrival order in one array. The two-stack version shows up in interviews ("implement a queue using two stacks") and is useful when the only primitive you have is a stack. In app code, an Array with an index is usually enough.

## A deque on a ring buffer

A deque needs O(1) at **both** ends, including adding at the front. A head index can't move backward past 0 in an ordinary array, but it can in a **ring buffer**: a fixed-size array where the slot after the last one is slot 0. The elements live in `count` consecutive slots starting at `head`, and "consecutive" wraps around.

```swift
struct Deque<Element> {
    private var storage: [Element?]
    private var head = 0
    private(set) var count = 0

    init(capacity: Int = 4) {
        storage = Array(repeating: nil, count: max(capacity, 1))
    }

    var isEmpty: Bool { count == 0 }
    var layout: String {
        storage.map { $0.map { "\($0)" } ?? "_" }.joined(separator: " ") + "  head: \(head)"
    }

    private func slot(_ offset: Int) -> Int {
        (head + offset) % storage.count
    }

    private mutating func growIfFull() {
        guard count == storage.count else { return }
        var bigger: [Element?] = Array(repeating: nil, count: storage.count * 2)
        for offset in 0..<count {
            bigger[offset] = storage[slot(offset)]
        }
        storage = bigger
        head = 0
    }

    mutating func pushBack(_ element: Element) {
        growIfFull()
        storage[slot(count)] = element
        count += 1
    }

    mutating func pushFront(_ element: Element) {
        growIfFull()
        head = (head - 1 + storage.count) % storage.count
        storage[head] = element
        count += 1
    }

    mutating func popFront() -> Element? {
        guard count > 0 else { return nil }
        let element = storage[head]
        storage[head] = nil
        head = slot(1)
        count -= 1
        return element
    }

    mutating func popBack() -> Element? {
        guard count > 0 else { return nil }
        let index = slot(count - 1)
        let element = storage[index]
        storage[index] = nil
        count -= 1
        return element
    }
}

var deque = Deque<Int>(capacity: 4)
deque.pushBack(1)
deque.pushBack(2)
deque.pushBack(3)
print(deque.layout)
_ = deque.popFront()
_ = deque.popFront()
deque.pushBack(4)
deque.pushBack(5)
print(deque.layout)
deque.pushFront(0)
print(deque.layout)
deque.pushBack(6)
print(deque.layout)
print(deque.popBack() ?? -1, deque.popFront() ?? -1, deque.count)
```

```output
1 2 3 _  head: 0
5 _ 3 4  head: 2
5 0 3 4  head: 1
0 3 4 5 6 _ _ _  head: 0
6 0 3
```

1. `storage` is an array of optionals, so an empty slot is `nil`. Setting a slot back to `nil` on pop also releases the element right away, which matters if it's a class instance.
2. `slot(offset)` turns "the offset-th element" into a storage index: `(head + offset) % capacity`. With capacity 4 and `head` 2, offsets 0, 1, 2, 3 map to slots 2, 3, 0, 1.
3. `pushBack` writes at `slot(count)`, the slot just past the last element.
4. `pushFront` moves `head` one slot back, **wrapping** from 0 to the last slot. The `+ storage.count` is there because Swift's `%` keeps the sign of the left operand, so `(0 - 1) % 4` is `-1`, not 3.
5. When the buffer is full, `growIfFull` copies the elements **in deque order** (front first) into an array twice as big and resets `head` to 0. That's O(n), but doubling makes it rare, and the same amortized argument as Array's `append` gives O(1) per push.

Read the second line of output: the front is 3 at slot 2, then 4 at slot 3, then the queue wraps to 5 at slot 0. No element moved when 1 and 2 left.

Every operation is O(1), with pushes amortized because of growth. Space is O(capacity), at most twice the number of elements after growth (this version never shrinks).

> [!note] A production deque
> Apple's open-source [swift-collections](https://github.com/apple/swift-collections) package has a `Deque` type implemented as a ring buffer. It isn't part of the standard library: you add the package with Swift Package Manager. For learning and interviews, write your own; in an app that needs a real deque, use the package's instead.

## Why queues matter: processing in discovery order

Queues decide **order**. Here's the case you'll meet again and again in later modules. An app's screens link to each other, and you want to know how many taps each screen is from Home. Start with Home in a queue. Repeatedly dequeue a screen and enqueue every linked screen you haven't seen yet:

```swift
let links: [String: [String]] = [
    "Home": ["Search", "Profile"],
    "Search": ["Results"],
    "Profile": ["Settings", "Friends"],
    "Results": ["Detail"],
    "Settings": [],
    "Friends": ["Detail"],
    "Detail": [],
]

var taps: [String: Int] = ["Home": 0]
var queue = ["Home"]
var head = 0
while head < queue.count {
    let screen = queue[head]
    head += 1
    print(taps[screen, default: 0], screen)
    for next in links[screen, default: []] where taps[next] == nil {
        taps[next] = taps[screen, default: 0] + 1
        queue.append(next)
    }
}
```

```output
0 Home
1 Search
1 Profile
2 Results
2 Settings
2 Friends
3 Detail
```

1. The queue is an array with a head index, the same idea as `Queue` above without the compaction (the array never holds more than the number of screens).
2. `taps` doubles as the "already seen" record: a screen gets its distance the moment it's discovered, and never again.
3. Everything one tap from Home is enqueued before anything two taps away, because those are only discovered while processing the one-tap screens. FIFO keeps that order, so screens come out **level by level**, and the first time you discover a screen is along a shortest route.

This is **breadth-first search**, and you'll study it properly in the graph modules. Swap the queue for a stack and the same loop goes deep before it goes wide: it would follow Home → Profile → Friends → Detail before looking at Search's branch, and the "taps" it records wouldn't be the shortest. The structure you choose **is** the algorithm.

## Common mistakes

> [!error] removeFirst() in a loop over a large queue
> Each call shifts every remaining element. A drain of n elements is O(n²). Use a head index, two stacks or a ring buffer.

> [!error] Fatal error: Index out of range after head - 1
> In a ring buffer, `(head - 1) % capacity` is `-1` when `head` is 0, because Swift's `%` keeps the left operand's sign. Add the capacity first: `(head - 1 + capacity) % capacity`.

```swift runtime-error Index out of range
var storage = [10, 20, 30, 40]
var head = 0
head = (head - 1) % storage.count
print("head is", head)
storage[head] = 5
```

```output
head is -1
```

> [!error] Copying a full ring buffer in storage order when growing
> If the buffer wrapped, storage order isn't queue order. Copy front to back with `storage[slot(offset)]` for offsets `0..<count`, then set `head` to 0.

> [!error] Refilling the outbox while it still has elements
> In a two-stack queue, move the inbox only when the outbox is empty. Otherwise newer elements land on top of older ones and come out first.

> [!error] A head-index queue that never compacts
> Dequeued elements stay in the array. A long-lived queue keeps growing, and if the elements are class instances, they're never released. Compact now and then, or set dequeued slots to `nil`.

## Exercises

````exercise
id: m17-l02-e1
type: comprehension
prompt: A queue built on an Array with a head index dequeues by reading items[head] and moving head forward, and compacts with removeFirst(head) when head reaches half of items.count. Which statement about its cost is correct?
choices:
  - text: Every dequeue is O(1), because no element ever moves.
    correct: false
    why: The compaction moves the remaining elements. The dequeue that triggers it is O(n).
  - text: A single dequeue can be O(n), but any sequence of n operations is O(n) in total, so dequeue is amortized O(1).
    correct: true
    why: A compaction moves at most head elements, and head dequeues happened since the last one. Each dequeue pays for one move.
  - text: Every dequeue is O(n), because removeFirst is O(n).
    correct: false
    why: removeFirst runs only during compaction, not on every dequeue.
  - text: It's O(log n) per dequeue, because the array halves at each compaction.
    correct: false
    why: Nothing halves repeatedly here. The cost is constant per operation on average, with occasional linear steps.
solution: |
  **Amortized O(1), with an occasional O(n) step.** Most dequeues just read a slot and add 1 to `head`. Compaction is O(n), but it only runs when the used prefix is at least half of the array, so the elements it moves (at most `head` of them) are paid for by the `head` cheap dequeues that came before it. That's what "amortized" promises: a bound on the total, not on each call.
````

````exercise
id: m17-l02-e2
type: prediction
prompt: "Predict the exact output. This is the two-stack queue from the lesson, with both stacks made visible so you can print their sizes after each dequeue."
code: |
  struct TwoStackQueue {
      var inbox: [Int] = []
      var outbox: [Int] = []

      mutating func dequeue() -> Int? {
          if outbox.isEmpty {
              while let element = inbox.popLast() {
                  outbox.append(element)
              }
          }
          return outbox.popLast()
      }
  }

  var queue = TwoStackQueue()
  queue.inbox.append(1)
  queue.inbox.append(2)
  print(queue.dequeue() ?? 0, queue.inbox.count, queue.outbox.count)
  queue.inbox.append(3)
  queue.inbox.append(4)
  print(queue.dequeue() ?? 0, queue.inbox.count, queue.outbox.count)
  print(queue.dequeue() ?? 0, queue.inbox.count, queue.outbox.count)
  print(queue.outbox, queue.inbox)
output: |
  1 0 1
  2 2 0
  3 0 1
  [4] []
hints:
  - Arguments are evaluated left to right, so each line dequeues before it reads the counts.
  - The first dequeue moves 1 and 2 to the outbox, reversing them, so 1 is on top.
  - The second dequeue finds the outbox non-empty (it holds 2), so it doesn't refill.
solution: |
  ```output
  1 0 1
  2 2 0
  3 0 1
  [4] []
  ```

  First dequeue: the outbox is empty, so 2 and then 1 are moved (outbox `[2, 1]`), and 1 is popped. Inbox 0, outbox 1. Then 3 and 4 are enqueued into the inbox. Second dequeue: the outbox still holds 2, so there's no refill; it pops 2. Inbox 2, outbox 0. Third dequeue: the outbox is empty, so 4 and then 3 move over (outbox `[4, 3]`), and 3 is popped, leaving `[4]`. The output order 1, 2, 3 is FIFO even though each array on its own is LIFO.
````

````exercise
id: m17-l02-e3
type: find-errors
prompt: This ring-buffer deque has bugs. Which statements are true?
code: |
  struct Deque {
      var storage: [Int?] = [nil, nil, nil, nil]
      var head = 0
      var count = 0

      mutating func pushFront(_ value: Int) {
          head = (head - 1) % storage.count
          storage[head] = value
          count += 1
      }

      mutating func grow() {
          var bigger: [Int?] = Array(repeating: nil, count: storage.count * 2)
          for index in 0..<count {
              bigger[index] = storage[index]
          }
          storage = bigger
          head = 0
      }
  }
choices:
  - text: The first pushFront on a new deque crashes with Index out of range.
    correct: true
    why: "head is 0, and (0 - 1) % 4 is -1 in Swift, so storage[-1] is out of range."
  - text: "grow() puts the elements in the wrong order when the buffer has wrapped around."
    correct: true
    why: It copies storage[0..<count] in storage order. The front is at head, not at 0, so the deque order is lost.
  - text: The deque would be faster as [Int] instead of [Int?].
    correct: false
    why: "Optionals mark empty slots and let pop release elements. They don't change the Big O."
  - text: "grow() is wrong because doubling makes pushes O(n) on average."
    correct: false
    why: Doubling is what keeps pushes amortized O(1), as with Array's append.
rubric:
  - I identified the negative remainder in pushFront.
  - I identified that grow copies in storage order instead of deque order.
  - "I fixed both: (head - 1 + capacity) % capacity, and copying storage[(head + offset) % capacity]."
  - I kept grow at O(n) and pushes at amortized O(1).
solution: |
  Both bugs are about wraparound:

  ```swift
  struct Deque {
      var storage: [Int?] = [nil, nil, nil, nil]
      var head = 0
      var count = 0

      mutating func pushFront(_ value: Int) {
          if count == storage.count { grow() }
          head = (head - 1 + storage.count) % storage.count
          storage[head] = value
          count += 1
      }

      mutating func grow() {
          var bigger: [Int?] = Array(repeating: nil, count: storage.count * 2)
          for offset in 0..<count {
              bigger[offset] = storage[(head + offset) % storage.count]
          }
          storage = bigger
          head = 0
      }
  }

  var deque = Deque()
  for value in 1...5 {
      deque.pushFront(value)
  }
  print(deque.storage, deque.head)
  ```

  ```output
  [Optional(4), Optional(3), Optional(2), Optional(1), nil, nil, nil, Optional(5)] 7
  ```

  Adding the capacity before `%` keeps the index non-negative. Copying by offset from `head` puts the front element at index 0 of the new storage, which is why `head` can reset to 0. The fixed version also calls `grow()` when the buffer is full, which the original never did. In the output, pushing 1 to 4 at the front filled the four slots backward, then the fifth push grew the buffer to `[4, 3, 2, 1, nil, …]` and wrapped `head` to the last slot to place 5. Read from `head` (slot 7) and wrap: 5, 4, 3, 2, 1, which is the reverse of the push order, as it should be.
````

````exercise
id: m17-l02-e4
type: fill-in
prompt: Complete the dequeue of this two-stack queue so the program prints `a b c`.
code: |
  struct TwoStackQueue {
      var inbox: [String] = []
      var outbox: [String] = []

      mutating func dequeue() -> String? {
          if outbox.[[1]] {
              while let element = inbox.[[2]]() {
                  outbox.append(element)
              }
          }
          return outbox.[[3]]()
      }
  }

  var queue = TwoStackQueue(inbox: ["a", "b"])
  let first = queue.dequeue() ?? "-"
  queue.inbox.append("c")
  print(first, queue.dequeue() ?? "-", queue.dequeue() ?? "-")
blanks:
  - id: "1"
    answers: ["isEmpty"]
  - id: "2"
    answers: ["popLast"]
  - id: "3"
    answers: ["popLast"]
solution: |
  ```swift
  struct TwoStackQueue {
      var inbox: [String] = []
      var outbox: [String] = []

      mutating func dequeue() -> String? {
          if outbox.isEmpty {
              while let element = inbox.popLast() {
                  outbox.append(element)
              }
          }
          return outbox.popLast()
      }
  }

  var queue = TwoStackQueue(inbox: ["a", "b"])
  let first = queue.dequeue() ?? "-"
  queue.inbox.append("c")
  print(first, queue.dequeue() ?? "-", queue.dequeue() ?? "-")
  ```

  ```output
  a b c
  ```

  Refill only when the outbox is empty, by popping the inbox from its top, which reverses the order. Then pop the outbox. Both pops are O(1). The refill is O(k) for k waiting elements, but each element is moved once in its life, so dequeue is amortized O(1). The memberwise initializer `TwoStackQueue(inbox:)` works because `outbox` has a default value.
````

````exercise
id: m17-l02-e5
type: solve
prompt: |
  A networking layer wants to know how many requests it sent in the last 3,000 ms, to throttle itself. Times arrive in non-decreasing order. Write a `RequestCounter` struct with `mutating func record(at time: Int) -> Int` that records a request at `time` and returns how many recorded requests are in the window `[time - 3000, time]`, including this one. Each call must be amortized O(1).

  Expected output for the starter's calls:

  ```output
  1 2 3 3 1
  ```
starter: |
  struct RequestCounter {
      // A queue of times: an array and a head index

      mutating func record(at time: Int) -> Int {
          return 0
      }
  }

  var counter = RequestCounter()
  let counts = [1, 100, 3001, 3002, 7000].map { counter.record(at: $0) }
  print(counts.map(String.init).joined(separator: " "))
hints:
  - The oldest request is the first one to fall out of the window. That's FIFO.
  - After enqueuing the new time, dequeue from the front while the front is older than time - 3000.
  - The answer is the number of elements between head and the end.
rubric:
  - Keeps the times in a FIFO queue without calling removeFirst() on every expiry.
  - Enqueues the new time, then drops times older than time - 3000 from the front.
  - Returns the count of times still in the queue, and the output matches.
  - Explains why each call is amortized O(1)
solution: |
  ```swift
  struct RequestCounter {
      private var times: [Int] = []
      private var head = 0

      mutating func record(at time: Int) -> Int {
          times.append(time)
          while times[head] < time - 3000 {
              head += 1
          }
          if head >= 64 && head * 2 >= times.count {
              times.removeFirst(head)
              head = 0
          }
          return times.count - head
      }
  }

  var counter = RequestCounter()
  let counts = [1, 100, 3001, 3002, 7000].map { counter.record(at: $0) }
  print(counts.map(String.init).joined(separator: " "))
  ```

  ```output
  1 2 3 3 1
  ```

  Times arrive in order, so the oldest one is always at the front, and it's the first to expire: a queue. At 3002 the window starts at 2, so the request at 1 leaves; at 7000 everything before 4000 leaves. The `while` can't run past the end, because the time just appended is never older than `time - 3000`. The `while` loop can run many times in one call, but each time is dequeued at most once in total, so over n calls it runs at most n times: **amortized O(1) per call**. Compaction is paid for the same way. Space is O(w), where w is the most requests in any 3,000 ms window, plus the prefix waiting for compaction. This is a sliding window from Module 16 with the window stored in a queue.
````

````exercise
id: m17-l02-e6
type: explain
prompt: |
  A teammate's code review comment says: "The two-stack queue isn't O(1). Look, `dequeue` has a `while` loop that moves every element. That's O(n)." Write a reply that explains who's right about what, and when the difference would actually matter in an app.
code: |
  mutating func dequeue() -> Element? {
      if outbox.isEmpty {
          while let element = inbox.popLast() {
              outbox.append(element)
          }
      }
      return outbox.popLast()
  }
rubric:
  - Agrees that a single dequeue can be O(n), when it refills the outbox.
  - Explains the amortized bound by counting how many times each element is moved.
  - States that n operations cost O(n) in total, so amortized O(1) each.
  - Names a case where worst-case latency matters (for example, work done on the main thread during scrolling) and how to avoid the spike.
solution: |
  You're both right, about different things. A **single** `dequeue` that finds the outbox empty moves every waiting element, so its worst case is O(n). But that bound is about one call. Count instead how many times each element is touched over its whole life: one push onto the inbox, one move to the outbox, one pop. Three O(1) steps, no matter how the calls interleave. So any sequence of n enqueues and dequeues costs O(n) in total, which is **amortized O(1)** per operation, the same guarantee Array's `append` gives.

  The difference matters when one slow call is visible. If this queue held a million elements and a dequeue ran on the main thread during scrolling, the refill could cost a frame, even though the average is fine. In that case, use a structure with a worst-case O(1) dequeue, such as a ring buffer, or move the work off the main thread. For most queues in an app, amortized O(1) is exactly what you want.
````

## Summary

- A **queue** is FIFO: enqueue at the back, dequeue from the front. A **deque** adds and removes at both ends.
- `removeFirst()` on an Array is O(n) because it shifts the rest, so draining a queue that way is O(n²).
- **Head-index queue**: read `items[head]` and move `head`; compact when the used prefix is at least half. Dequeue is amortized O(1).
- **Two-stack queue**: push onto an inbox; pop from an outbox, refilling it from the inbox only when it's empty. Each element moves at most three times, so operations are amortized O(1).
- **Ring-buffer deque**: indexes wrap with `%`, `head - 1` needs `+ capacity` first, and growth copies in deque order. All operations O(1), pushes amortized.
- Processing with a queue handles items in **discovery order**, level by level (breadth-first). A stack goes deep first. The structure decides the order.
