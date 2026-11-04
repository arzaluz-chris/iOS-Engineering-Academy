import Testing
@testable import Challenges

@Suite("Product of Array Except Self")
struct ProductOfArrayExceptSelfTests {
    @Test("Examples from the problem statement")
    func examples() {
        #expect(productsExceptSelf([2, 3, 4, 5]) == [60, 40, 30, 24])
        #expect(productsExceptSelf([-1, 2, 0, 4]) == [0, 0, -8, 0])
        #expect(productsExceptSelf([0, 3, 0]) == [0, 0, 0])
    }

    @Test("Empty, one and two elements")
    func tiny() {
        #expect(productsExceptSelf([]) == [])
        #expect(productsExceptSelf([7]) == [1])
        #expect(productsExceptSelf([3, -4]) == [-4, 3])
    }

    @Test("Exactly one zero")
    func oneZero() {
        #expect(productsExceptSelf([1, 2, 0, 3]) == [0, 0, 6, 0])
    }

    @Test("Agrees with the naive solution on random arrays")
    func agreesWithBruteForce() {
        var generator = SeededGenerator(seed: 9)
        for _ in 0..<1_000 {
            let nums = (0..<generator.next(below: 9)).map { _ in generator.next(below: 11) - 5 }
            #expect(productsExceptSelf(nums) == productsExceptSelfBruteForce(nums))
        }
    }
}

/// Small deterministic generator (a linear congruential generator) so failures reproduce.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// A value in `0..<bound`.
    mutating func next(below bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}
