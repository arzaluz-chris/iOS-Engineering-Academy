import Testing
@testable import Challenges

@Suite("Expression Add Operators")
struct ExpressionsReachingTargetTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(Set(expressionsReachingTarget("124", target: 7)) == ["1+2+4"])
        #expect(Set(expressionsReachingTarget("232", target: 8)) == ["2*3+2", "2+3*2"])
        #expect(Set(expressionsReachingTarget("105", target: 5)) == ["1*0+5", "10-5"])
        #expect(expressionsReachingTarget("37", target: 1) == [])
    }

    @Test("Multiplication binds tighter than + and -")
    func precedence() {
        #expect(Set(expressionsReachingTarget("123", target: 7)) == ["1+2*3"])
        #expect(Set(expressionsReachingTarget("123", target: 9)) == ["12-3"])
        #expect(Set(expressionsReachingTarget("2357", target: -103)) == ["2-3*5*7"])
    }

    @Test("Operands with a leading zero aren't allowed")
    func leadingZeros() {
        #expect(!expressionsReachingTarget("105", target: 6).contains("1+05"))
        #expect(Set(expressionsReachingTarget("00", target: 0)) == ["0+0", "0-0", "0*0"])
        #expect(expressionsReachingTarget("012", target: 12) == ["0+12"])
    }

    @Test("Single digit and the whole string as one number")
    func wholeNumber() {
        #expect(expressionsReachingTarget("7", target: 7) == ["7"])
        #expect(expressionsReachingTarget("7", target: 3) == [])
        #expect(expressionsReachingTarget("9999999999", target: 9_999_999_999).contains("9999999999"))
    }

    @Test("Empty input has no expressions")
    func empty() {
        #expect(expressionsReachingTarget("", target: 0) == [])
    }

    @Test("Negative targets")
    func negativeTarget() {
        #expect(Set(expressionsReachingTarget("123", target: -4)) == ["1-2-3"])
    }

    @Test("Every expression returned evaluates to the target")
    func resultsEvaluate() {
        let result = expressionsReachingTarget("123456", target: 21)
        #expect(!result.isEmpty)
        #expect(result.allSatisfy { expressionsReachingTargetEvaluate($0) == 21 })
    }

    @Test("Agrees with evaluating all 4^(n-1) expressions on random inputs")
    func agreesWithBruteForce() {
        var random = LCG(state: 58)
        for _ in 0..<200 {
            let digits = String((0..<random.next(1...6)).map { _ in Character(String(random.next(0...9))) })
            let target = random.next(-30...60)
            #expect(Set(expressionsReachingTarget(digits, target: target))
                == Set(expressionsReachingTargetBruteForce(digits, target: target)))
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
