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

@Suite("Min Stack")
struct MinStackTests {
    @Test("Example from the problem statement")
    func example() {
        var stack = MinStack()
        stack.push(5)
        stack.push(3)
        stack.push(7)
        #expect(stack.minimum() == 3)
        #expect(stack.pop() == 7)
        #expect(stack.minimum() == 3)
        #expect(stack.pop() == 3)
        #expect(stack.minimum() == 5)
        #expect(stack.top() == 5)
    }

    @Test("Empty stack returns nil everywhere")
    func empty() {
        var stack = MinStack()
        #expect(stack.isEmpty)
        #expect(stack.top() == nil)
        #expect(stack.minimum() == nil)
        #expect(stack.pop() == nil)
        stack.push(1)
        stack.pop()
        #expect(stack.minimum() == nil)
    }

    @Test("A repeated minimum survives popping one copy")
    func duplicateMinimum() {
        var stack = MinStack()
        stack.push(2)
        stack.push(1)
        stack.push(1)
        stack.pop()
        #expect(stack.minimum() == 1)
        stack.pop()
        #expect(stack.minimum() == 2)
    }

    @Test("Negative numbers and Int extremes")
    func extremes() {
        var stack = MinStack()
        stack.push(Int.max)
        stack.push(-4)
        stack.push(Int.min)
        #expect(stack.minimum() == Int.min)
        stack.pop()
        #expect(stack.minimum() == -4)
    }

    @Test("Random operations agree with the naive stack")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(state: 17)
        var fast = MinStack()
        var slow = MinStackBruteForce()
        for _ in 0..<5_000 {
            if generator.next(below: 3) == 0 {
                #expect(fast.pop() == slow.pop())
            } else {
                let value = generator.next(below: 41) - 20
                fast.push(value)
                slow.push(value)
            }
            #expect(fast.top() == slow.top())
            #expect(fast.minimum() == slow.minimum())
            #expect(fast.isEmpty == slow.isEmpty)
        }
    }
}
