import Testing
@testable import Challenges

@Suite("Integer Square Root")
struct IntegerSquareRootTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(integerSquareRoot(16) == 4)
        #expect(integerSquareRoot(20) == 4)
        #expect(integerSquareRoot(1) == 1)
        #expect(integerSquareRoot(0) == 0)
    }

    @Test("Values right below and at a perfect square")
    func aroundPerfectSquares() {
        #expect(integerSquareRoot(24) == 4)
        #expect(integerSquareRoot(25) == 5)
        #expect(integerSquareRoot(2) == 1)
        #expect(integerSquareRoot(3) == 1)
        #expect(integerSquareRoot(4) == 2)
    }

    @Test("The largest Int doesn't overflow")
    func largestInt() {
        #expect(integerSquareRoot(Int.max) == 3_037_000_499)
        #expect(integerSquareRoot(3_037_000_499 * 3_037_000_499) == 3_037_000_499)
        #expect(integerSquareRoot(3_037_000_499 * 3_037_000_499 - 1) == 3_037_000_498)
    }

    @Test("Agrees with the naive count for 0 through 20,000")
    func agreesWithBruteForce() {
        for n in 0...20_000 {
            #expect(integerSquareRoot(n) == integerSquareRootBruteForce(n))
        }
    }

    @Test("The result is the floor of the square root on large random values")
    func randomLarge() {
        var random = LCG(state: 44)
        for _ in 0..<2_000 {
            let n = random.next(0...Int.max - 1)
            let root = integerSquareRoot(n)
            #expect(root * root <= n)
            let next = (root + 1).multipliedReportingOverflow(by: root + 1)
            #expect(next.overflow || next.partialValue > n)
        }
    }
}

/// Small deterministic generator so failures reproduce.
private struct LCG {
    var state: UInt64
    mutating func next(_ range: ClosedRange<Int>) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return range.lowerBound + Int((state >> 33) % UInt64(range.count))
    }
}
