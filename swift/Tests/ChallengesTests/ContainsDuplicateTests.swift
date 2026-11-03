import Testing
@testable import Challenges

@Suite("Contains Duplicate")
struct ContainsDuplicateTests {
    static let cases: [([Int], Bool)] = [
        ([1, 2, 3, 1], true),
        ([1, 2, 3, 4], false),
        ([1, 1, 1, 3, 3, 4, 3, 2, 4, 2], true),
        ([], false),
        ([7], false),
        ([-1, -1], true),
        ([0, Int.max, Int.min], false),
    ]

    @Test("With a Set", arguments: ContainsDuplicateTests.cases)
    func withSet(input: [Int], expected: Bool) {
        #expect(containsDuplicate(input) == expected)
    }

    @Test("By sorting", arguments: ContainsDuplicateTests.cases)
    func bySorting(input: [Int], expected: Bool) {
        #expect(containsDuplicateBySorting(input) == expected)
    }

    @Test("Duplicate at the end of a large list")
    func duplicateAtEnd() {
        let input = Array(0..<10_000) + [9_999]
        #expect(containsDuplicate(input))
    }
}
