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

    @Test("Con Set", arguments: ContainsDuplicateTests.cases)
    func conSet(input: [Int], expected: Bool) {
        #expect(containsDuplicate(input) == expected)
    }

    @Test("Ordenando", arguments: ContainsDuplicateTests.cases)
    func ordenando(input: [Int], expected: Bool) {
        #expect(containsDuplicateBySorting(input) == expected)
    }

    @Test("El duplicado al final de una lista grande")
    func duplicadoAlFinal() {
        let input = Array(0..<10_000) + [9_999]
        #expect(containsDuplicate(input))
    }
}
