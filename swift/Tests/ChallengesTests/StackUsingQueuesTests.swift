import Testing
@testable import Challenges

/// Deterministic pseudo-random numbers (a 64-bit LCG), so a failing case reproduces.
private struct SeededGenerator {
    var state: UInt64
    mutating func next(below bound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
}

@Suite("Implement a Stack Using a Queue")
struct StackUsingQueuesTests {
    @Test("Example from the problem statement")
    func example() {
        var stack = QueueBackedStack<String>()
        stack.push("Inbox")
        stack.push("Thread")
        stack.push("Attachment")
        #expect(stack.top() == "Attachment")
        #expect(stack.pop() == "Attachment")
        #expect(stack.pop() == "Thread")
        stack.push("Settings")
        #expect(stack.count == 2)
        #expect(stack.pop() == "Settings")
        #expect(stack.pop() == "Inbox")
        #expect(stack.isEmpty)
    }

    @Test("Empty stack")
    func empty() {
        var stack = QueueBackedStack<Int>()
        #expect(stack.isEmpty)
        #expect(stack.count == 0)
        #expect(stack.top() == nil)
        #expect(stack.pop() == nil)
    }

    @Test("A single element is both pushed and popped")
    func single() {
        var stack = QueueBackedStack<Int>()
        stack.push(42)
        #expect(stack.top() == 42)
        #expect(stack.pop() == 42)
        #expect(stack.pop() == nil)
    }

    @Test("The provided queue is first in, first out")
    func queueIsFIFO() {
        var queue = OneWayQueue<Int>()
        for value in 0..<100 {
            queue.enqueue(value)
        }
        for value in 0..<100 {
            #expect(queue.dequeue() == value)
        }
        #expect(queue.dequeue() == nil)
    }

    @Test("Random operations agree with an Array used as a stack and with the two-queue version")
    func agreesWithReference() {
        var generator = SeededGenerator(state: 5)
        var stack = QueueBackedStack<Int>()
        var naive = QueueBackedStackBruteForce<Int>()
        var reference: [Int] = []
        for step in 0..<3_000 {
            if generator.next(below: 5) < 2 {
                let expected = reference.popLast()
                #expect(stack.pop() == expected)
                #expect(naive.pop() == expected)
            } else {
                stack.push(step)
                naive.push(step)
                reference.append(step)
            }
            #expect(stack.top() == reference.last)
            #expect(naive.top() == reference.last)
            #expect(stack.count == reference.count)
            #expect(naive.count == reference.count)
        }
    }
}
