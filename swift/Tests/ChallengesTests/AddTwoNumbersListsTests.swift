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

/// Builds a digit list from digits given least significant first.
private func makeList(_ digits: [Int]) -> DigitListNode? {
    var head: DigitListNode? = nil
    for digit in digits.reversed() {
        head = DigitListNode(digit, next: head)
    }
    return head
}

/// Builds a digit list for a non-negative Int.
private func makeList(number: Int) -> DigitListNode? {
    var digits: [Int] = []
    var remaining = number
    repeat {
        digits.append(remaining % 10)
        remaining /= 10
    } while remaining > 0
    return makeList(digits)
}

private func digits(_ head: DigitListNode?) -> [Int] {
    var result: [Int] = []
    var current = head
    while let node = current {
        result.append(node.digit)
        current = node.next
    }
    return result
}

@Suite("Add Two Numbers as Linked Lists")
struct AddTwoNumbersListsTests {
    @Test("Examples from the problem statement")
    func examples() {
        // 465 + 78 = 543
        #expect(digits(addDigitLists(makeList([5, 6, 4]), makeList([8, 7]))) == [3, 4, 5])
        // 0 + 0 = 0
        #expect(digits(addDigitLists(makeList([0]), makeList([0]))) == [0])
        // 999 + 1 = 1000
        #expect(digits(addDigitLists(makeList([9, 9, 9]), makeList([1]))) == [0, 0, 0, 1])
    }

    @Test("Lists of different lengths, in either order")
    func differentLengths() {
        #expect(digits(addDigitLists(makeList([1]), makeList([2, 3, 4]))) == [3, 3, 4])
        #expect(digits(addDigitLists(makeList([2, 3, 4]), makeList([1]))) == [3, 3, 4])
    }

    @Test("Empty lists count as zero")
    func emptyLists() {
        #expect(addDigitLists(nil, nil) == nil)
        #expect(digits(addDigitLists(nil, makeList([7, 2]))) == [7, 2])
    }

    @Test("Numbers too big for Int")
    func hugeNumbers() {
        // (10^40 - 1) + 1 = 10^40
        let nines = makeList(Array(repeating: 9, count: 40))
        #expect(digits(addDigitLists(nines, makeList([1]))) == Array(repeating: 0, count: 40) + [1])
    }

    @Test("The inputs aren't modified")
    func inputsUnchanged() {
        let a = makeList([9, 9])
        let b = makeList([3])
        _ = addDigitLists(a, b)
        #expect(digits(a) == [9, 9])
        #expect(digits(b) == [3])
    }

    @Test("Random numbers agree with Int addition and with the naive version")
    func agreesWithIntAddition() {
        var generator = SeededGenerator(state: 8)
        for _ in 0..<500 {
            let x = generator.next(below: 1_000_000_000)
            let y = generator.next(below: [10, 1_000, 1_000_000_000][generator.next(below: 3)])
            let sum = addDigitLists(makeList(number: x), makeList(number: y))
            #expect(digits(sum) == digits(makeList(number: x + y)), "\(x) + \(y)")
            #expect(digits(sum) == digits(addDigitListsViaInt(makeList(number: x), makeList(number: y))))
        }
    }
}
