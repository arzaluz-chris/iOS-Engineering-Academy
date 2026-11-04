---
id: stack-using-queue
title: Implement a Stack Using a Queue
difficulty: easy
order: 31
patterns: [Queue, Stack, Data structure design]
prerequisites: [m17-l01, m17-l02]
summary: Build last-in, first-out behavior when the only tool you have is a first-in, first-out queue. Rotate the queue after every push.
solutionFile: StackUsingQueues.swift
testFile: StackUsingQueuesTests.swift
starter: |
  // Use this queue as given. Don't touch its internals from the stack.
  struct OneWayQueue<Element> {
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

  struct QueueBackedStack<Element> {
      private var queue = OneWayQueue<Element>()

      var isEmpty: Bool { true }
      var count: Int { 0 }

      func top() -> Element? {
          nil
      }

      mutating func push(_ element: Element) {
          // Your solution
      }

      @discardableResult
      mutating func pop() -> Element? {
          nil
      }
  }
time: push O(n); pop, top, count and isEmpty O(1) (pop amortized)
space: O(n)
edgeCases:
  - pop and top on an empty stack return nil
  - A single element pushed and popped
  - Pushes and pops interleaved, not all pushes first
askInterviewer:
  - Which queue operations am I allowed to use? Can I read the front without removing it?
  - Can I use more than one queue?
  - Which operation will be called most often? Should push or pop be the cheap one?
hints:
  - A queue gives back the oldest element, and a stack needs the newest. Right after a push, where is the newest element in the queue?
  - Dequeuing an element and enqueuing it again moves it from the front to the back without losing it. How many times do you do that to bring the newest element to the front?
  - Rotate count - 1 times after each enqueue. Then the queue's front is always the stack's top.
followUps:
  - Make push O(1) and pop O(n) instead. When is that the better trade?
  - Lesson m17-l02 built a queue from two stacks with O(1) amortized operations. Why can't the reverse trick make this one amortized O(1)?
  - Where does this kind of adapter show up in real code? (Wrapping a system API that only gives you FIFO access, like a serial work queue.)
rubric:
  - I used only enqueue, dequeue, front, count and isEmpty on the queue.
  - I rotated the queue after each push so the newest element is at the front.
  - I gave the cost of each operation and said which one pays.
  - I returned nil from pop and top on an empty stack.
codeStatus: tested
---

A sync engine you're integrating gives you exactly one data structure: `OneWayQueue`, a first-in, first-out queue with `enqueue`, `dequeue`, `front`, `count` and `isEmpty` (it's in the starter; use it as is). You need a last-in, first-out stack for a screen history. Implement `QueueBackedStack` using **only** queue operations on a single `OneWayQueue`:

- `push(_:)` adds an element on top.
- `pop() -> Element?` removes and returns the top element, or `nil` if the stack is empty.
- `top() -> Element?` reads the top element without removing it.
- `count` and `isEmpty`.

```swift
var stack = QueueBackedStack<String>()
stack.push("Inbox")
stack.push("Thread")
stack.push("Attachment")
stack.top()    // "Attachment"
stack.pop()    // "Attachment"
stack.pop()    // "Thread"
stack.push("Settings")
stack.count    // 2
stack.pop()    // "Settings"
stack.pop()    // "Inbox"
stack.pop()    // nil
```

**Constraints:** up to 10^4 operations. You may not read the queue's internal array.

<!-- reveal -->

## First approach

The queue hands back the oldest element; the stack must hand back the newest. Something has to pay to reverse that. Lesson m17-l02 went the other way, a queue from two stacks, and moving elements between stacks reversed their order for free. Moving elements between queues keeps their order, so the trick here is different: rotate one queue until the newest element is at the front.

## Naive solution

Two queues. Push enqueues on the main one. Pop moves everything except the last element to the spare queue, takes the last one, and swaps the queues:

```swift
struct QueueBackedStack<Element> {
    private var main = OneWayQueue<Element>()
    private var spare = OneWayQueue<Element>()

    var isEmpty: Bool { main.isEmpty }
    var count: Int { main.count }

    mutating func push(_ element: Element) {
        main.enqueue(element)
    }

    mutating func top() -> Element? {
        guard let newest = pop() else { return nil }
        push(newest)
        return newest
    }

    @discardableResult
    mutating func pop() -> Element? {
        while main.count > 1, let element = main.dequeue() {
            spare.enqueue(element)
        }
        let newest = main.dequeue()
        swap(&main, &spare)
        return newest
    }
}
```

## Problems with the naive solution

`pop` is **O(n)**, and so is `top`, which has to pop and push back. Reading the top changes the structure, so `top()` has to be `mutating`, which is surprising for a method that only reads. Two queues also mean twice the bookkeeping. If you're going to pay O(n) somewhere, it's better to pay it once per push and leave the queue in an order where everything else is O(1).

## Optimized solution

Keep the queue in stack order: front = top. To push, enqueue the new element at the back, then dequeue and re-enqueue each of the `count - 1` older elements. They all go behind the new one, in their original order, so the new element ends up at the front and everything below it keeps its place. Now `pop` is a plain `dequeue`, and `top()` is `front`.

## Line by line

- `private var queue = OneWayQueue<Element>()`: the only storage. `private` keeps callers from enqueuing directly and breaking the order.
- `top()` returns `queue.front`: after every push, the front is the newest element. `front` returns `nil` when the queue is empty.
- `queue.enqueue(element)`: the new element starts at the back.
- `for _ in 0..<(queue.count - 1)`: one rotation step for each older element. With a single element, the range is `0..<0` and nothing moves.
- `if let older = queue.dequeue() { queue.enqueue(older) }`: moves the front element to the back. The `if let` unwraps the optional `dequeue()` result; inside this loop it's never `nil`.
- `queue.dequeue()` in `pop`: removes the front, which is the top. On an empty queue it returns `nil`.

Push does count − 1 rotations, each an amortized O(1) dequeue and enqueue: **O(n)**. `pop` is amortized O(1) (the queue occasionally compacts), and `top`, `count` and `isEmpty` are O(1). **O(n) space** for n elements.

## Common mistakes

- Rotating `count` times instead of `count - 1`. That puts the new element back at the end, where it started.
- Rotating before enqueuing the new element instead of after.
- Reading the queue's internal array (or using `removeLast()` on it) to reach the back. That works, but it isn't a queue anymore, and it's exactly what the problem forbids.
- Claiming the rotation is O(1) amortized. Unlike the two-stack queue, every push rotates the whole queue, so a sequence of n pushes costs O(n²).

## Variation

**Queue from two stacks** (lesson m17-l02) is the mirror problem, and it does get amortized O(1), because each element moves from the inbox to the outbox at most once. Comparing the two is a good interview answer: moving between stacks reverses order, which is what a queue needs; moving between queues preserves order, so you have to rotate.
