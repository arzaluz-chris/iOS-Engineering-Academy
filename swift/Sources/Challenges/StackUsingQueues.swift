/// A FIFO queue that only offers queue operations. It's the one building block the challenge allows.
/// Built on an Array with a head index; enqueue and dequeue are amortized O(1).
public struct OneWayQueue<Element> {
    private var items: [Element] = []
    private var head = 0

    public init() {}

    public var isEmpty: Bool { head == items.count }
    public var count: Int { items.count - head }
    public var front: Element? { isEmpty ? nil : items[head] }

    public mutating func enqueue(_ element: Element) {
        items.append(element)
    }

    public mutating func dequeue() -> Element? {
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

/// A LIFO stack built on a single `OneWayQueue`.
///
/// After each push, the queue is rotated so the new element is at the front:
/// every older element is dequeued and enqueued again behind it. The front of the queue
/// is then always the top of the stack.
/// push is O(n); pop, top, isEmpty and count are O(1) (pop amortized). O(n) space.
public struct QueueBackedStack<Element> {
    private var queue = OneWayQueue<Element>()

    public init() {}

    public var isEmpty: Bool { queue.isEmpty }
    public var count: Int { queue.count }

    /// The top element, or `nil` if the stack is empty.
    public func top() -> Element? {
        queue.front
    }

    public mutating func push(_ element: Element) {
        queue.enqueue(element)
        for _ in 0..<(queue.count - 1) {
            if let older = queue.dequeue() {
                queue.enqueue(older)
            }
        }
    }

    @discardableResult
    public mutating func pop() -> Element? {
        queue.dequeue()
    }
}

/// Naive version with two queues: push is O(1), but pop and top move every element except
/// the newest to the other queue to reach it, which is O(n) for each of them.
public struct QueueBackedStackBruteForce<Element> {
    private var main = OneWayQueue<Element>()
    private var spare = OneWayQueue<Element>()

    public init() {}

    public var isEmpty: Bool { main.isEmpty }
    public var count: Int { main.count }

    public mutating func push(_ element: Element) {
        main.enqueue(element)
    }

    public mutating func top() -> Element? {
        guard let newest = pop() else { return nil }
        push(newest)
        return newest
    }

    @discardableResult
    public mutating func pop() -> Element? {
        while main.count > 1, let element = main.dequeue() {
            spare.enqueue(element)
        }
        let newest = main.dequeue()
        swap(&main, &spare)
        return newest
    }
}
